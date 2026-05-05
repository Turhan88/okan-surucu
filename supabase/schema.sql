-- =====================================================
-- OKAN SÜRÜCÜ KURSLARI — DATABASE SCHEMA v1.0
-- Supabase / PostgreSQL
-- =====================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── UPDATED_AT TRIGGER ─────────────────────────────
CREATE OR REPLACE FUNCTION trigger_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

-- ── PROFILES (Supabase Auth role extension) ─────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL CHECK (role IN ('admin','teacher')),
  teacher_id  UUID,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION trigger_updated_at();

-- ── TEACHERS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.teachers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  first_name  TEXT NOT NULL,
  last_name   TEXT NOT NULL,
  sicil_no    TEXT UNIQUE NOT NULL,
  phone       TEXT,
  is_active   BOOLEAN DEFAULT TRUE NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  is_deleted  BOOLEAN DEFAULT FALSE NOT NULL,
  deleted_at  TIMESTAMPTZ,
  deleted_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL
);
CREATE TRIGGER teachers_updated_at
  BEFORE UPDATE ON public.teachers FOR EACH ROW EXECUTE FUNCTION trigger_updated_at();
CREATE INDEX idx_teachers_sicil  ON public.teachers(sicil_no) WHERE NOT is_deleted;
CREATE INDEX idx_teachers_active ON public.teachers(is_active)  WHERE NOT is_deleted;

-- ── STUDENTS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.students (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id  UUID NOT NULL REFERENCES public.teachers(id),
  first_name  TEXT NOT NULL,
  last_name   TEXT NOT NULL,
  tc_no       TEXT NOT NULL,
  phone       TEXT,
  notes       TEXT,
  is_active   BOOLEAN DEFAULT TRUE NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  is_deleted  BOOLEAN DEFAULT FALSE NOT NULL,
  deleted_at  TIMESTAMPTZ,
  deleted_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  UNIQUE(tc_no)
);
CREATE TRIGGER students_updated_at
  BEFORE UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION trigger_updated_at();
CREATE INDEX idx_students_teacher ON public.students(teacher_id) WHERE NOT is_deleted;
CREATE INDEX idx_students_tc      ON public.students(tc_no)      WHERE NOT is_deleted;

-- ── EXAMS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.exams (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id  UUID NOT NULL REFERENCES public.students(id),
  teacher_id  UUID NOT NULL REFERENCES public.teachers(id),
  exam_date   DATE NOT NULL,
  exam_type   TEXT DEFAULT 'direksiyon',
  score       NUMERIC(5,2),
  result      TEXT NOT NULL CHECK (result IN ('passed','failed','sick','not-taken')),
  notes       TEXT,
  created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  is_deleted  BOOLEAN DEFAULT FALSE NOT NULL,
  deleted_at  TIMESTAMPTZ,
  deleted_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL
);
CREATE TRIGGER exams_updated_at
  BEFORE UPDATE ON public.exams FOR EACH ROW EXECUTE FUNCTION trigger_updated_at();
CREATE INDEX idx_exams_student ON public.exams(student_id) WHERE NOT is_deleted;
CREATE INDEX idx_exams_teacher ON public.exams(teacher_id) WHERE NOT is_deleted;

-- ── SURVEYS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.surveys (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id   UUID NOT NULL REFERENCES public.students(id),
  teacher_id   UUID NOT NULL REFERENCES public.teachers(id),
  month        TEXT NOT NULL,        -- YYYY-MM
  avg_score    NUMERIC(4,2),
  submitted_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  is_deleted   BOOLEAN DEFAULT FALSE NOT NULL,
  deleted_at   TIMESTAMPTZ,
  UNIQUE(student_id, teacher_id)
);
CREATE TRIGGER surveys_updated_at
  BEFORE UPDATE ON public.surveys FOR EACH ROW EXECUTE FUNCTION trigger_updated_at();
CREATE INDEX idx_surveys_teacher ON public.surveys(teacher_id) WHERE NOT is_deleted;
CREATE INDEX idx_surveys_month   ON public.surveys(month)      WHERE NOT is_deleted;

-- ── SURVEY ANSWERS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.survey_answers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id     UUID NOT NULL REFERENCES public.surveys(id) ON DELETE CASCADE,
  question_key  TEXT NOT NULL,
  answer_value  TEXT NOT NULL,
  score_value   NUMERIC(4,2),
  created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_survey_answers ON public.survey_answers(survey_id);

-- ── BONUS THRESHOLDS (configurable) ─────────────────
CREATE TABLE IF NOT EXISTS public.bonus_thresholds (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label         TEXT NOT NULL,
  min_score     NUMERIC(4,2) NOT NULL,
  max_score     NUMERIC(4,2) NOT NULL,
  bonus_amount  NUMERIC(10,2) NOT NULL,
  sort_order    INTEGER DEFAULT 0,
  is_active     BOOLEAN DEFAULT TRUE NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE TRIGGER bonus_thresholds_updated_at
  BEFORE UPDATE ON public.bonus_thresholds FOR EACH ROW EXECUTE FUNCTION trigger_updated_at();

-- ── BONUSES (monthly snapshot) ───────────────────────
CREATE TABLE IF NOT EXISTS public.bonuses (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id       UUID NOT NULL REFERENCES public.teachers(id),
  month            TEXT NOT NULL,
  survey_count     INTEGER DEFAULT 0,
  avg_score        NUMERIC(4,2),
  bonus_amount     NUMERIC(10,2) DEFAULT 0,
  threshold_label  TEXT,
  is_paid          BOOLEAN DEFAULT FALSE,
  paid_at          TIMESTAMPTZ,
  calculated_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  created_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(teacher_id, month)
);
CREATE TRIGGER bonuses_updated_at
  BEFORE UPDATE ON public.bonuses FOR EACH ROW EXECUTE FUNCTION trigger_updated_at();
CREATE INDEX idx_bonuses_teacher ON public.bonuses(teacher_id);
CREATE INDEX idx_bonuses_month   ON public.bonuses(month);

-- ── AUDIT LOGS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  role        TEXT,
  action      TEXT NOT NULL,
  table_name  TEXT,
  record_id   TEXT,
  old_data    JSONB,
  new_data    JSONB,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX idx_audit_user   ON public.audit_logs(user_id);
CREATE INDEX idx_audit_action ON public.audit_logs(action);
CREATE INDEX idx_audit_date   ON public.audit_logs(created_at DESC);

-- ── HELPER FUNCTIONS (used in RLS) ──────────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(EXISTS(
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ), FALSE);
$$;

CREATE OR REPLACE FUNCTION public.my_teacher_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT teacher_id FROM profiles WHERE id = auth.uid() AND role = 'teacher';
$$;

-- ── STUDENT RPC: get by TC (no auth needed) ──────────
CREATE OR REPLACE FUNCTION public.get_student_by_tc(p_tc_no TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result JSON;
BEGIN
  SELECT json_build_object(
    'id',          s.id,
    'first_name',  s.first_name,
    'last_name',   s.last_name,
    'tc_masked',   CONCAT(LEFT(s.tc_no,3),'*****',RIGHT(s.tc_no,2)),
    'teacher_id',  s.teacher_id,
    'teacher_name', t.first_name || ' ' || t.last_name,
    'has_survey',  EXISTS(
      SELECT 1 FROM surveys sv
      WHERE sv.student_id = s.id AND sv.teacher_id = s.teacher_id AND NOT sv.is_deleted
    ),
    'exams', (
      SELECT COALESCE(json_agg(json_build_object(
        'exam_date', e.exam_date,
        'exam_type', e.exam_type,
        'score',     e.score,
        'result',    e.result,
        'notes',     e.notes
      ) ORDER BY e.exam_date DESC), '[]')
      FROM exams e WHERE e.student_id = s.id AND NOT e.is_deleted
    )
  ) INTO v_result
  FROM students s
  JOIN teachers t ON t.id = s.teacher_id
  WHERE s.tc_no = p_tc_no AND NOT s.is_deleted AND s.is_active;
  RETURN v_result;
END;
$$;

-- ── STUDENT RPC: get active teachers (for dropdown) ──
CREATE OR REPLACE FUNCTION public.get_active_teachers()
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result JSON;
BEGIN
  SELECT json_agg(json_build_object(
    'id',         t.id,
    'first_name', t.first_name,
    'last_name',  t.last_name,
    'sicil_no',   t.sicil_no
  ) ORDER BY t.first_name, t.last_name) INTO v_result
  FROM teachers t
  WHERE t.is_active AND NOT t.is_deleted;
  RETURN COALESCE(v_result, '[]');
END;
$$;

-- ── STUDENT RPC: submit survey (no auth, validates TC) ─
CREATE OR REPLACE FUNCTION public.submit_survey_by_tc(
  p_tc_no     TEXT,
  p_teacher_id UUID,
  p_answers   JSONB
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_student_id UUID;
  v_survey_id  UUID;
  v_avg        NUMERIC(4,2);
  v_total      NUMERIC := 0;
  v_count      INTEGER := 0;
  v_ans        JSONB;
BEGIN
  SELECT id INTO v_student_id FROM students
  WHERE tc_no = p_tc_no AND NOT is_deleted AND is_active;
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Kursiyer bulunamadı.';
  END IF;

  IF EXISTS(SELECT 1 FROM surveys
    WHERE student_id = v_student_id AND teacher_id = p_teacher_id AND NOT is_deleted) THEN
    RAISE EXCEPTION 'Bu öğretmen için zaten anket doldurdunuz.';
  END IF;

  FOR v_ans IN SELECT * FROM jsonb_array_elements(p_answers) LOOP
    v_total := v_total + COALESCE((v_ans->>'score_value')::NUMERIC, 0);
    v_count := v_count + 1;
  END LOOP;
  IF v_count > 0 THEN v_avg := ROUND(v_total / v_count, 2); END IF;

  INSERT INTO surveys(student_id, teacher_id, month, avg_score)
  VALUES(v_student_id, p_teacher_id, TO_CHAR(NOW(),'YYYY-MM'), v_avg)
  RETURNING id INTO v_survey_id;

  FOR v_ans IN SELECT * FROM jsonb_array_elements(p_answers) LOOP
    INSERT INTO survey_answers(survey_id, question_key, answer_value, score_value)
    VALUES(v_survey_id, v_ans->>'question_key', v_ans->>'answer_value',
           (v_ans->>'score_value')::NUMERIC);
  END LOOP;

  INSERT INTO audit_logs(action, table_name, record_id, new_data)
  VALUES('SUBMIT_SURVEY', 'surveys', v_survey_id::TEXT,
         jsonb_build_object('teacher_id', p_teacher_id, 'avg_score', v_avg));

  RETURN json_build_object('success', true, 'survey_id', v_survey_id, 'avg_score', v_avg);
END;
$$;

-- ── BONUS CALCULATION FUNCTION ────────────────────────
CREATE OR REPLACE FUNCTION public.calculate_monthly_bonus(p_teacher_id UUID, p_month TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_count   INTEGER;
  v_avg     NUMERIC(4,2);
  v_bonus   NUMERIC(10,2) := 0;
  v_label   TEXT := 'Prim Yok';
  v_thresh  RECORD;
BEGIN
  SELECT COUNT(*), AVG(avg_score)
  INTO v_count, v_avg
  FROM surveys
  WHERE teacher_id = p_teacher_id AND month = p_month AND NOT is_deleted;

  IF v_count > 0 THEN
    SELECT bonus_amount, label INTO v_bonus, v_label
    FROM bonus_thresholds
    WHERE is_active AND v_avg >= min_score AND v_avg <= max_score
    ORDER BY bonus_amount DESC LIMIT 1;
  END IF;

  INSERT INTO bonuses(teacher_id, month, survey_count, avg_score, bonus_amount, threshold_label)
  VALUES(p_teacher_id, p_month, v_count, v_avg, COALESCE(v_bonus,0), v_label)
  ON CONFLICT(teacher_id, month) DO UPDATE SET
    survey_count    = EXCLUDED.survey_count,
    avg_score       = EXCLUDED.avg_score,
    bonus_amount    = EXCLUDED.bonus_amount,
    threshold_label = EXCLUDED.threshold_label,
    calculated_at   = NOW(),
    updated_at      = NOW();

  RETURN json_build_object(
    'teacher_id', p_teacher_id, 'month', p_month,
    'survey_count', v_count, 'avg_score', v_avg,
    'bonus_amount', COALESCE(v_bonus,0), 'label', v_label
  );
END;
$$;
