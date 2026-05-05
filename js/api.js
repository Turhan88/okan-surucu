'use strict';

// All API calls. Requires supabase-client.js loaded first.

const API = {

  // ── AUTH ──────────────────────────────────────────
  async loginAdmin(email, password) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    const { data: profile } = await supabase.from('profiles').select('role').eq('id', data.user.id).single();
    if (!profile || profile.role !== 'admin') {
      await supabase.auth.signOut();
      throw new Error('Bu hesap yönetici değil.');
    }
    return data;
  },

  async loginTeacher(sicilNo, password) {
    const email = `${sicilNo.trim()}@okan.internal`;
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw new Error('Sicil no veya şifre hatalı.');
    const { data: profile } = await supabase.from('profiles').select('role,teacher_id').eq('id', data.user.id).single();
    if (!profile || profile.role !== 'teacher') {
      await supabase.auth.signOut();
      throw new Error('Bu hesap öğretmen değil.');
    }
    return { session: data, teacherId: profile.teacher_id };
  },

  async logout() {
    await supabase.auth.signOut();
  },

  async getSession() {
    const { data } = await supabase.auth.getSession();
    return data.session;
  },

  async getMyProfile() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return null;
    const { data } = await supabase.from('profiles').select('role,teacher_id').eq('id', user.id).single();
    return data ? { ...data, userId: user.id } : null;
  },

  // ── TEACHERS ─────────────────────────────────────
  async getTeachers({ includeDeleted = false } = {}) {
    let q = supabase.from('teachers').select('*').order('first_name');
    if (!includeDeleted) q = q.eq('is_deleted', false);
    const { data, error } = await q;
    if (error) throw error;
    return data;
  },

  async getTeacher(id) {
    const { data, error } = await supabase.from('teachers').select('*').eq('id', id).single();
    if (error) throw error;
    return data;
  },

  async createTeacher(formData) {
    const { data: { session } } = await supabase.auth.getSession();
    const res = await fetch('/api/create-teacher', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session.access_token}`
      },
      body: JSON.stringify(formData)
    });
    const json = await res.json();
    if (!res.ok) throw new Error(json.error || 'Öğretmen oluşturulamadı.');
    await this.auditLog('CREATE_TEACHER', 'teachers', json.teacher?.id, null, formData);
    return json.teacher;
  },

  async updateTeacher(id, updates) {
    const old = await this.getTeacher(id);
    const { data, error } = await supabase.from('teachers').update(updates).eq('id', id).select().single();
    if (error) throw error;
    await this.auditLog('UPDATE_TEACHER', 'teachers', id, old, updates);
    return data;
  },

  async deactivateTeacher(teacherId) {
    const { data: { session } } = await supabase.auth.getSession();
    const res = await fetch('/api/deactivate-teacher', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session.access_token}`
      },
      body: JSON.stringify({ teacherId })
    });
    const json = await res.json();
    if (!res.ok) throw new Error(json.error || 'Öğretmen devre dışı bırakılamadı.');
    return json;
  },

  async reactivateTeacher(id, authUserId) {
    const { data, error } = await supabase.from('teachers').update({
      is_active: true, is_deleted: false, deleted_at: null, deleted_by: null
    }).eq('id', id).select().single();
    if (error) throw error;
    await this.auditLog('REACTIVATE_TEACHER', 'teachers', id, null, { id });
    return data;
  },

  // ── STUDENTS ─────────────────────────────────────
  async getStudents({ teacherId = null, search = '', includeDeleted = false } = {}) {
    let q = supabase.from('students').select('*, teachers(first_name,last_name)').order('first_name');
    if (!includeDeleted) q = q.eq('is_deleted', false);
    if (teacherId) q = q.eq('teacher_id', teacherId);
    if (search) q = q.or(`first_name.ilike.%${search}%,last_name.ilike.%${search}%,tc_no.ilike.%${search}%`);
    const { data, error } = await q;
    if (error) throw error;
    return data;
  },

  async getStudent(id) {
    const { data, error } = await supabase.from('students').select('*').eq('id', id).single();
    if (error) throw error;
    return data;
  },

  async createStudent(formData) {
    const { data, error } = await supabase.from('students').insert(formData).select().single();
    if (error) throw new Error(error.code === '23505' ? 'Bu TC kimlik no zaten kayıtlı.' : error.message);
    await this.auditLog('CREATE_STUDENT', 'students', data.id, null, { ...formData, tc_no: '***' });
    return data;
  },

  async updateStudent(id, updates) {
    const { data, error } = await supabase.from('students').update(updates).eq('id', id).select().single();
    if (error) throw error;
    return data;
  },

  async softDeleteStudent(id) {
    const { data: { user } } = await supabase.auth.getUser();
    const old = await this.getStudent(id);
    const { error } = await supabase.from('students').update({
      is_deleted: true, is_active: false,
      deleted_at: new Date().toISOString(), deleted_by: user.id
    }).eq('id', id);
    if (error) throw error;
    await this.auditLog('DELETE_STUDENT', 'students', id, { name: old.first_name+' '+old.last_name }, null);
  },

  // ── EXAMS ──────────────────────────────────────────
  async getExams(studentId) {
    const { data, error } = await supabase.from('exams')
      .select('*').eq('student_id', studentId).eq('is_deleted', false).order('exam_date', { ascending: false });
    if (error) throw error;
    return data;
  },

  async addExam(formData) {
    const { data: { user } } = await supabase.auth.getUser();
    const { data, error } = await supabase.from('exams')
      .insert({ ...formData, created_by: user.id }).select().single();
    if (error) throw error;
    await this.auditLog('ADD_EXAM', 'exams', data.id, null, formData);
    return data;
  },

  async softDeleteExam(id) {
    const { data: { user } } = await supabase.auth.getUser();
    const { error } = await supabase.from('exams').update({
      is_deleted: true, deleted_at: new Date().toISOString(), deleted_by: user.id
    }).eq('id', id);
    if (error) throw error;
  },

  // ── SURVEYS ────────────────────────────────────────
  async getSurveys({ teacherId = null, month = null, dateFrom = null, dateTo = null } = {}) {
    let q = supabase.from('surveys')
      .select('*, teachers(first_name,last_name), students(first_name,last_name,tc_no)')
      .eq('is_deleted', false)
      .order('submitted_at', { ascending: false });
    if (teacherId) q = q.eq('teacher_id', teacherId);
    if (month)     q = q.eq('month', month);
    if (dateFrom)  q = q.gte('submitted_at', dateFrom);
    if (dateTo)    q = q.lte('submitted_at', dateTo + 'T23:59:59');
    const { data, error } = await q;
    if (error) throw error;
    return data;
  },

  async getSurveyAnswers(surveyId) {
    const { data, error } = await supabase.from('survey_answers')
      .select('*').eq('survey_id', surveyId).order('question_key');
    if (error) throw error;
    return data;
  },

  // ── STUDENT (no-auth) RPC ─────────────────────────
  async getStudentByTc(tcNo) {
    const { data, error } = await supabase.rpc('get_student_by_tc', { p_tc_no: tcNo });
    if (error) throw error;
    return data;
  },

  async getActiveTeachers() {
    const { data, error } = await supabase.rpc('get_active_teachers');
    if (error) throw error;
    return data || [];
  },

  async submitSurveyByTc(tcNo, teacherId, answers) {
    const { data, error } = await supabase.rpc('submit_survey_by_tc', {
      p_tc_no: tcNo, p_teacher_id: teacherId, p_answers: answers
    });
    if (error) throw new Error(error.message);
    return data;
  },

  // ── BONUS THRESHOLDS ──────────────────────────────
  async getThresholds() {
    const { data, error } = await supabase.from('bonus_thresholds')
      .select('*').eq('is_active', true).order('sort_order');
    if (error) throw error;
    return data;
  },

  async updateThreshold(id, updates) {
    const { data, error } = await supabase.from('bonus_thresholds').update(updates).eq('id', id).select().single();
    if (error) throw error;
    await this.auditLog('UPDATE_THRESHOLD', 'bonus_thresholds', id, null, updates);
    return data;
  },

  // ── BONUSES ───────────────────────────────────────
  async calculateBonus(teacherId, month) {
    const { data, error } = await supabase.rpc('calculate_monthly_bonus', {
      p_teacher_id: teacherId, p_month: month
    });
    if (error) throw error;
    return data;
  },

  async getBonuses(month) {
    let q = supabase.from('bonuses')
      .select('*, teachers(first_name,last_name,sicil_no)')
      .order('bonus_amount', { ascending: false });
    if (month) q = q.eq('month', month);
    const { data, error } = await q;
    if (error) throw error;
    return data;
  },

  async markBonusPaid(id) {
    const { data, error } = await supabase.from('bonuses').update({
      is_paid: true, paid_at: new Date().toISOString()
    }).eq('id', id).select().single();
    if (error) throw error;
    return data;
  },

  // ── AUDIT LOG ─────────────────────────────────────
  async auditLog(action, tableName, recordId, oldData, newData) {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      const { data: profile }  = await supabase.from('profiles').select('role').eq('id', user?.id).single();
      await supabase.from('audit_logs').insert({
        user_id: user?.id, role: profile?.role,
        action, table_name: tableName,
        record_id: recordId ? String(recordId) : null,
        old_data: oldData || null, new_data: newData || null
      });
    } catch { /* audit errors should never break main flow */ }
  },

  async getAuditLogs({ limit = 100, offset = 0 } = {}) {
    const { data, error } = await supabase.from('audit_logs')
      .select('*').order('created_at', { ascending: false }).range(offset, offset + limit - 1);
    if (error) throw error;
    return data;
  }
};
