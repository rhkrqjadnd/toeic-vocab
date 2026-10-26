// Vercel 서버리스 함수: 관리자 전용 작업 (비밀번호 초기화, 사용자 삭제)
// Vercel 프로젝트 환경변수에 SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY 를 넣어야 동작합니다.
// service role 키는 절대 브라우저 코드(config.js)에 넣지 마세요.
const { createClient } = require('@supabase/supabase-js');

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  const url = process.env.SUPABASE_URL, key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) return res.status(500).json({ error: '서버 환경변수(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)가 없습니다' });

  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ error: '로그인이 필요합니다' });

  const admin = createClient(url, key, { auth: { persistSession: false } });
  const { data: who, error: e1 } = await admin.auth.getUser(token);
  if (e1 || !who || !who.user) return res.status(401).json({ error: '토큰이 유효하지 않습니다' });

  const { data: prof } = await admin.from('profiles').select('role,status').eq('id', who.user.id).single();
  if (!prof || prof.role !== 'admin' || prof.status !== 'approved') return res.status(403).json({ error: '관리자만 사용할 수 있습니다' });

  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch (e) { body = {}; } }
  const { action, user_id, password } = body || {};
  if (!user_id) return res.status(400).json({ error: 'user_id가 필요합니다' });
  if (user_id === who.user.id && action === 'delete_user') return res.status(400).json({ error: '자기 자신은 삭제할 수 없습니다' });

  try {
    if (action === 'reset_password') {
      if (!password || password.length < 6) return res.status(400).json({ error: '비밀번호는 6자 이상' });
      const { error } = await admin.auth.admin.updateUserById(user_id, { password });
      if (error) throw error;
      return res.json({ ok: true });
    }
    if (action === 'delete_user') {
      const { error } = await admin.auth.admin.deleteUser(user_id);
      if (error) throw error;
      return res.json({ ok: true });
    }
    return res.status(400).json({ error: '알 수 없는 action' });
  } catch (e) {
    return res.status(500).json({ error: e.message || String(e) });
  }
};
