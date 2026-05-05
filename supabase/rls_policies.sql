-- =====================================================
-- OKAN SÜRÜCÜ KURSLARI — ROW LEVEL SECURITY POLICIES
-- =====================================================
-- Run AFTER schema.sql

-- ── PROFILES ────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_own_read"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- ── TEACHERS ────────────────────────────────────────
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;

-- Admin: full read (including soft-deleted for audit)
CREATE POLICY "teachers_admin_read"
  ON public.teachers FOR SELECT
  USING (public.is_admin());

-- Admin: insert/update (no hard delete)
CREATE POLICY "teachers_admin_write"
  ON public.teachers FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "teachers_admin_update"
  ON public.teachers FOR UPDATE
  USING (public.is_admin());

-- Teacher: read own record only
CREATE POLICY "teachers_self_read"
  ON public.teachers FOR SELECT
  USING (user_id = auth.uid() AND NOT is_deleted);

-- ── STUDENTS ────────────────────────────────────────
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- Admin: full read
CREATE POLICY "students_admin_read"
  ON public.students FOR SELECT
  USING (public.is_admin());

-- Admin: insert/update
CREATE POLICY "students_admin_insert"
  ON public.students FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "students_admin_update"
  ON public.students FOR UPDATE
  USING (public.is_admin());

-- Teacher: only own students
CREATE POLICY "students_teacher_read"
  ON public.students FOR SELECT
  USING (teacher_id = public.my_teacher_id() AND NOT is_deleted);

CREATE POLICY "students_teacher_insert"
  ON public.students FOR INSERT
  WITH CHECK (teacher_id = public.my_teacher_id());

CREATE POLICY "students_teacher_update"
  ON public.students FOR UPDATE
  USING (teacher_id = public.my_teacher_id() AND NOT is_deleted);

-- ── EXAMS ────────────────────────────────────────────
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exams_admin_read"
  ON public.exams FOR SELECT USING (public.is_admin());

CREATE POLICY "exams_admin_insert"
  ON public.exams FOR INSERT WITH CHECK (public.is_admin());

CREATE POLICY "exams_admin_update"
  ON public.exams FOR UPDATE USING (public.is_admin());

CREATE POLICY "exams_teacher_read"
  ON public.exams FOR SELECT
  USING (teacher_id = public.my_teacher_id() AND NOT is_deleted);

CREATE POLICY "exams_teacher_insert"
  ON public.exams FOR INSERT
  WITH CHECK (teacher_id = public.my_teacher_id());

CREATE POLICY "exams_teacher_update"
  ON public.exams FOR UPDATE
  USING (teacher_id = public.my_teacher_id() AND NOT is_deleted);

-- ── SURVEYS ─────────────────────────────────────────
ALTER TABLE public.surveys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "surveys_admin_read"
  ON public.surveys FOR SELECT USING (public.is_admin());

CREATE POLICY "surveys_admin_update"
  ON public.surveys FOR UPDATE USING (public.is_admin());

-- Teacher: own surveys
CREATE POLICY "surveys_teacher_read"
  ON public.surveys FOR SELECT
  USING (teacher_id = public.my_teacher_id() AND NOT is_deleted);

-- Surveys are inserted only via submit_survey_by_tc RPC (security definer)
-- No direct insert policy needed for anon

-- ── SURVEY ANSWERS ───────────────────────────────────
ALTER TABLE public.survey_answers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "survey_answers_admin"
  ON public.survey_answers FOR SELECT USING (public.is_admin());

CREATE POLICY "survey_answers_teacher"
  ON public.survey_answers FOR SELECT
  USING (
    EXISTS(
      SELECT 1 FROM surveys s
      WHERE s.id = survey_id AND s.teacher_id = public.my_teacher_id() AND NOT s.is_deleted
    )
  );

-- ── BONUS THRESHOLDS ─────────────────────────────────
ALTER TABLE public.bonus_thresholds ENABLE ROW LEVEL SECURITY;

-- Everyone can read thresholds (teachers see their potential bonus)
CREATE POLICY "bonus_thresholds_read_all"
  ON public.bonus_thresholds FOR SELECT USING (TRUE);

-- Only admin can modify
CREATE POLICY "bonus_thresholds_admin_write"
  ON public.bonus_thresholds FOR INSERT WITH CHECK (public.is_admin());

CREATE POLICY "bonus_thresholds_admin_update"
  ON public.bonus_thresholds FOR UPDATE USING (public.is_admin());

-- ── BONUSES ──────────────────────────────────────────
ALTER TABLE public.bonuses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bonuses_admin_all"
  ON public.bonuses FOR ALL USING (public.is_admin());

CREATE POLICY "bonuses_teacher_own"
  ON public.bonuses FOR SELECT
  USING (teacher_id = public.my_teacher_id());

-- ── AUDIT LOGS ───────────────────────────────────────
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Only admin can read audit logs
CREATE POLICY "audit_admin_read"
  ON public.audit_logs FOR SELECT USING (public.is_admin());

-- Inserts only via security definer functions (no direct INSERT policy for users)
-- Use service_role for inserts from Netlify Functions
