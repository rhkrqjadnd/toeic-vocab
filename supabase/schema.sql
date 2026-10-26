-- 토익 보카 트레이너 · Supabase 스키마
-- Supabase 대시보드 → SQL Editor → New query 에 전체를 붙여 넣고 Run 하세요. 여러 번 실행해도 안전합니다.

-- 1) 프로필 (가입 시 자동 생성, 관리자가 승인)
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text unique not null,
  name        text not null default '',
  org         text not null default '',
  role        text not null default 'learner' check (role in ('learner','admin')),
  status      text not null default 'pending' check (status in ('pending','approved','blocked')),
  created_at  timestamptz not null default now(),
  approved_at timestamptz
);

-- 2) 단어별 학습 상태
create table if not exists public.word_state (
  user_id   uuid not null references public.profiles(id) on delete cascade,
  word      text not null,
  level     smallint not null default 0,
  sc        int not null default 0,   -- 연속 정답
  sw        int not null default 0,   -- 연속 오답
  tc        int not null default 0,   -- 누적 정답
  tw        int not null default 0,   -- 누적 오답
  mastered  boolean not null default false,
  last_seen bigint not null default 0, -- epoch ms
  primary key (user_id, word)
);

-- 3) 일별 기록
create table if not exists public.daily_log (
  user_id uuid not null references public.profiles(id) on delete cascade,
  date    date not null,
  n       int not null default 0,
  ok      int not null default 0,
  counts  jsonb not null default '{}'::jsonb, -- {word: 오늘 노출 수}
  primary key (user_id, date)
);

-- 4) 개인 추가/수정 단어
create table if not exists public.user_words (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  word       text not null,
  meaning    text not null default '',
  pos        text not null default '',
  example    text not null default '',
  example_ko text not null default '',
  synonyms   text not null default '',
  derivatives text not null default '',
  tag        text not null default '',
  rank       int not null default 0,
  primary key (user_id, word)
);

-- 5) 개인 설정
create table if not exists public.settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  data    jsonb not null default '{}'::jsonb
);

-- 6) 관리자 대시보드용 요약 (클라이언트가 학습 후 갱신)
create table if not exists public.progress_summary (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- 가입 시 auth.users → profiles 자동 생성 (아이디/이름/소속은 가입 폼의 metadata에서)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, name, org)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'name',''),
    coalesce(new.raw_user_meta_data->>'org','')
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 권한 판별 함수 (RLS 안에서 재귀 없이 쓰기 위해 security definer)
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin' and status = 'approved');
$$;
create or replace function public.is_approved()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and status = 'approved');
$$;

-- RLS 켜기
alter table public.profiles         enable row level security;
alter table public.word_state       enable row level security;
alter table public.daily_log        enable row level security;
alter table public.user_words       enable row level security;
alter table public.settings         enable row level security;
alter table public.progress_summary enable row level security;

-- profiles: 본인은 자기 행 읽기, 관리자는 전체 읽기/수정
drop policy if exists "profiles self read"   on public.profiles;
drop policy if exists "profiles admin read"  on public.profiles;
drop policy if exists "profiles admin write" on public.profiles;
create policy "profiles self read"   on public.profiles for select using (id = auth.uid());
create policy "profiles admin read"  on public.profiles for select using (public.is_admin());
create policy "profiles admin write" on public.profiles for update using (public.is_admin()) with check (public.is_admin());

-- 학습 데이터: 승인된 본인만 읽기/쓰기, 관리자는 전체 읽기
do $$
declare t text;
begin
  foreach t in array array['word_state','daily_log','user_words','settings','progress_summary'] loop
    execute format('drop policy if exists "own rw" on public.%I', t);
    execute format('drop policy if exists "admin read" on public.%I', t);
    execute format('create policy "own rw" on public.%I for all using (user_id = auth.uid() and public.is_approved()) with check (user_id = auth.uid() and public.is_approved())', t);
    execute format('create policy "admin read" on public.%I for select using (public.is_admin())', t);
  end loop;
end $$;

-- 아이디 중복 확인용 (로그인 전에도 호출 가능)
create or replace function public.username_taken(u text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where username = lower(u));
$$;
grant execute on function public.username_taken(text) to anon, authenticated;

-- ----------------------------------------------------------------
-- 첫 관리자 지정: 사이트에서 아이디 rhksflwk 로 먼저 가입한 뒤, 이 파일을 다시 Run 하면 관리자로 승격됩니다 (가입 전에는 아무 일도 하지 않음)
update public.profiles set role='admin', status='approved', approved_at=now() where username='rhksflwk';
-- ----------------------------------------------------------------
