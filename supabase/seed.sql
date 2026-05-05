-- =====================================================
-- OKAN SÜRÜCÜ KURSLARI — SEED DATA
-- Run AFTER schema.sql and rls_policies.sql
-- =====================================================

-- ── BONUS THRESHOLDS (configurable prim eşikleri) ───
INSERT INTO public.bonus_thresholds (label, min_score, max_score, bonus_amount, sort_order) VALUES
  ('Üst Prim',   4.50, 5.00, 5000.00, 1),
  ('Orta Prim',  4.00, 4.49, 4000.00, 2),
  ('Düşük Prim', 3.50, 3.99, 3000.00, 3),
  ('Teşvik',     3.00, 3.49, 1000.00, 4)
ON CONFLICT DO NOTHING;

-- ── ADMIN USER SETUP (manual steps required) ─────────
-- 1. Supabase Dashboard → Authentication → Users → "Add User"
--    Email: admin@okan.internal
--    Password: <güçlü şifre belirleyin>
--    Email Confirm: TRUE
--
-- 2. After creating the user, get the user UUID from auth.users
--    and run the following INSERT (replace UUID):
--
-- INSERT INTO public.profiles (id, role)
-- VALUES ('<AUTH_USER_UUID_HERE>', 'admin');
--
-- ── NOTES ─────────────────────────────────────────────
-- Teachers are created via the Netlify Function /create-teacher
-- which automatically creates auth.users entry + profiles + teachers rows.
-- Do NOT create teachers manually in auth.users without running the function.
