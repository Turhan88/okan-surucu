/**
 * Creates a new teacher account.
 * Requires: valid admin JWT in Authorization header.
 * Uses SERVICE_ROLE_KEY — never exposed to frontend.
 */
const { createClient } = require('@supabase/supabase-js');

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST')
    return { statusCode: 405, body: 'Method Not Allowed' };

  const authHeader = event.headers['authorization'] || event.headers['Authorization'];
  if (!authHeader)
    return { statusCode: 401, body: JSON.stringify({ error: 'Yetki gerekli.' }) };

  const userClient = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_ANON_KEY,
    { global: { headers: { Authorization: authHeader } } }
  );

  // Verify admin
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user)
    return { statusCode: 401, body: JSON.stringify({ error: 'Geçersiz oturum.' }) };

  const { data: profile } = await userClient.from('profiles').select('role').eq('id', user.id).single();
  if (!profile || profile.role !== 'admin')
    return { statusCode: 403, body: JSON.stringify({ error: 'Sadece yönetici bu işlemi yapabilir.' }) };

  let body;
  try { body = JSON.parse(event.body); }
  catch { return { statusCode: 400, body: JSON.stringify({ error: 'Geçersiz istek gövdesi.' }) }; }

  const { firstName, lastName, sicilNo, phone, password } = body;
  if (!firstName || !lastName || !sicilNo || !password)
    return { statusCode: 400, body: JSON.stringify({ error: 'Ad, soyad, sicil no ve şifre zorunludur.' }) };

  const adminClient = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );

  const email = `${sicilNo.trim()}@okan.internal`;

  // Create auth user
  const { data: authData, error: authCreateErr } = await adminClient.auth.admin.createUser({
    email, password, email_confirm: true
  });
  if (authCreateErr)
    return { statusCode: 400, body: JSON.stringify({ error: authCreateErr.message }) };

  const authUserId = authData.user.id;

  // Create teacher record
  const { data: teacher, error: teacherErr } = await adminClient
    .from('teachers')
    .insert({ user_id: authUserId, first_name: firstName, last_name: lastName, sicil_no: sicilNo.trim(), phone: phone || null })
    .select().single();

  if (teacherErr) {
    await adminClient.auth.admin.deleteUser(authUserId);
    return { statusCode: 400, body: JSON.stringify({ error: teacherErr.message }) };
  }

  // Create profile
  const { error: profileErr } = await adminClient
    .from('profiles')
    .insert({ id: authUserId, role: 'teacher', teacher_id: teacher.id });

  if (profileErr) {
    await adminClient.auth.admin.deleteUser(authUserId);
    await adminClient.from('teachers').delete().eq('id', teacher.id);
    return { statusCode: 400, body: JSON.stringify({ error: profileErr.message }) };
  }

  // Audit log
  await adminClient.from('audit_logs').insert({
    user_id: user.id, role: 'admin', action: 'CREATE_TEACHER',
    table_name: 'teachers', record_id: teacher.id,
    new_data: { firstName, lastName, sicilNo, phone }
  });

  return { statusCode: 200, body: JSON.stringify({ success: true, teacher }) };
};
