/**
 * Soft-deactivates a teacher (is_deleted=true + bans auth user).
 * Requires: valid admin JWT.
 */
const { createClient } = require('@supabase/supabase-js');

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST')
    return { statusCode: 405, body: 'Method Not Allowed' };

  const authHeader = event.headers['authorization'] || event.headers['Authorization'];
  if (!authHeader)
    return { statusCode: 401, body: JSON.stringify({ error: 'Yetki gerekli.' }) };

  const userClient = createClient(
    process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY,
    { global: { headers: { Authorization: authHeader } } }
  );
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return { statusCode: 401, body: JSON.stringify({ error: 'Geçersiz oturum.' }) };

  const { data: profile } = await userClient.from('profiles').select('role').eq('id', user.id).single();
  if (!profile || profile.role !== 'admin')
    return { statusCode: 403, body: JSON.stringify({ error: 'Sadece yönetici bu işlemi yapabilir.' }) };

  let body;
  try { body = JSON.parse(event.body); }
  catch { return { statusCode: 400, body: JSON.stringify({ error: 'Geçersiz istek.' }) }; }

  const { teacherId } = body;
  if (!teacherId) return { statusCode: 400, body: JSON.stringify({ error: 'teacherId gerekli.' }) };

  const adminClient = createClient(
    process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY
  );

  // Fetch teacher to get user_id
  const { data: teacher } = await adminClient.from('teachers').select('user_id, first_name, last_name').eq('id', teacherId).single();
  if (!teacher) return { statusCode: 404, body: JSON.stringify({ error: 'Öğretmen bulunamadı.' }) };

  // Soft delete teacher
  await adminClient.from('teachers').update({
    is_deleted: true, is_active: false,
    deleted_at: new Date().toISOString(), deleted_by: user.id
  }).eq('id', teacherId);

  // Ban auth user (prevents login, preserves data)
  if (teacher.user_id) {
    await adminClient.auth.admin.updateUserById(teacher.user_id, { ban_duration: '876600h' }); // ~100 years
  }

  // Audit log
  await adminClient.from('audit_logs').insert({
    user_id: user.id, role: 'admin', action: 'DEACTIVATE_TEACHER',
    table_name: 'teachers', record_id: teacherId,
    old_data: { name: teacher.first_name + ' ' + teacher.last_name }
  });

  return { statusCode: 200, body: JSON.stringify({ success: true }) };
};
