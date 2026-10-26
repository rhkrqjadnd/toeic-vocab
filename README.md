# 토익 보카 트레이너 — 설치 안내

아이디/비밀번호 가입 → 관리자 승인 → 학습, 관리자가 전체 학습 현황을 감독하는 웹사이트입니다.
구성: 정적 사이트(index.html) + Supabase(회원·DB) + Vercel(호스팅, 관리자 API).

## 폴더 구성

| 파일 | 역할 |
|---|---|
| `index.html` | 앱 전체(가입·로그인·학습·단어장·설정·관리자) |
| `words.json` | 기본 단어장 5,000개 (교체 가능) |
| `config.js` | Supabase 주소와 anon 키 (직접 입력) |
| `supabase/schema.sql` | DB 테이블·권한 규칙 (Supabase SQL Editor에서 1회 실행) |
| `api/admin.js` | 관리자 전용 서버 함수(비밀번호 초기화·계정 삭제) |
| `manifest.json`, `icon-*.png` | 휴대폰 "홈 화면에 추가"용 |

## 1단계 — Supabase (약 10분)

1. https://supabase.com 가입 → **New project** → 이름 `toeic-vocab`, Region **Northeast Asia (Seoul)**, DB 비밀번호는 아무거나 정해 메모.
2. 왼쪽 **SQL Editor** → New query → `supabase/schema.sql` 내용을 전부 붙여 넣고 **Run**. "Success" 가 나오면 됩니다.
3. **Authentication → Providers → Email** 에서 **Confirm email 을 끕니다(OFF)**. 아이디 전용 가입이라 이메일 확인 메일을 보낼 수 없기 때문입니다. 저장.
4. **Settings → API** 에서 두 값을 복사:
   - `Project URL` → `config.js`의 `SUPABASE_URL`
   - `anon public` 키 → `config.js`의 `SUPABASE_ANON_KEY`
   - `service_role` 키는 **Vercel 환경변수에만** 넣습니다(3단계). 코드에 넣지 마세요.

## 2단계 — GitHub에 올리기

1. https://github.com 가입 → **New repository** → 이름 `toeic-vocab`, Private 권장 → Create.
2. 이 폴더의 파일을 모두 올립니다(웹에서 "Add file → Upload files"로 끌어다 놓아도 됩니다). `config.js`는 1단계 값을 넣은 뒤 올리세요.

## 3단계 — Vercel 배포 (약 5분)

1. https://vercel.com 가입(GitHub로 로그인) → **Add New → Project** → `toeic-vocab` 저장소 **Import**.
2. Framework Preset은 **Other** 그대로, Build 설정은 비워 둡니다.
3. **Environment Variables** 에 두 개 추가:
   - `SUPABASE_URL` = Project URL
   - `SUPABASE_SERVICE_ROLE_KEY` = service_role 키
4. **Deploy**. 1~2분 뒤 `https://toeic-vocab-xxxx.vercel.app` 주소가 생깁니다. Settings → Domains에서 주소를 바꾸거나 내 도메인을 연결할 수 있습니다.

## 4단계 — 첫 관리자 만들기

1. 배포된 사이트에서 **가입 신청**으로 아이디 `rhksflwk` 계정을 만듭니다. 비밀번호는 영문·숫자·특수문자만 사용해 6자 이상(한글 불가)이며, 가입 화면에서 직접 입력합니다.
2. Supabase **SQL Editor** 에서 아래를 실행(`schema.sql` 맨 아래에도 같은 줄이 있어 그 파일을 다시 Run 해도 됩니다):
   ```sql
   update public.profiles set role='admin', status='approved', approved_at=now() where username='rhksflwk';
   ```
3. 사이트에서 로그인하면 하단에 **관리** 탭이 보입니다. 이후 다른 관리자는 관리 탭에서 역할을 바꿔 지정하면 됩니다.

## 운영

- **가입 승인**: 관리 → 사용자 관리에서 대기 중인 사람을 승인/차단. 승인 전에는 로그인해도 "승인 대기 중" 화면만 보입니다.
- **학습 현황**: 관리 → 학습 현황에서 학습자별 오늘/7일 노출, 정답률, 숙지도 분포, 연속일을 보고, 행을 누르면 14일 추이와 취약 단어가 나옵니다.
- **비밀번호 초기화 / 계정 삭제**: 사용자 행의 `…` 버튼. (Vercel 환경변수가 있어야 동작)
- **단어장 교체**: `words.json`을 같은 형식(`[word, meaning, pos, example, example_ko, synonyms, derivatives, tag, rank]`)으로 바꿔 올리면 모든 사용자에게 반영됩니다. 학습자 개인은 단어장 탭에서 CSV를 추가할 수 있습니다.
- **휴대폰 설치**: 사이트 주소를 열고 Chrome 메뉴 → "홈 화면에 추가"(안드로이드), Safari 공유 → "홈 화면에 추가"(아이폰).

## 코드 수정이 필요할 때

폴더를 PC에 내려받아 터미널에서 `claude`(Claude Code)를 실행하고, 예를 들어 "index.html의 세션 종료 화면에 평균 응답 시간을 추가해 줘"처럼 지시하면 됩니다. GitHub에 push하면 Vercel이 자동으로 다시 배포합니다.

## 무료 범위

Supabase 무료: DB 500MB, 월 활성 사용자 5만 명 — 학습자 수백 명까지는 충분합니다(사용자 1명당 5,000행 ≈ 0.5MB).
Vercel 무료(Hobby): 개인·비상업 용도. 기관 공식 서비스로 쓰려면 Pro(월 20달러) 전환이 약관상 필요합니다.
