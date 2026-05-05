# OKAN SÜRÜCÜ KURSLARI — Production Checklist

## ADIM 1: Supabase Projesi Kurulumu

1. [supabase.com](https://supabase.com) → "New Project" oluşturun
2. Proje adı: `okan-surucu-kursu` (ya da istediğiniz bir isim)
3. Database şifresini güvenli bir yerde saklayın
4. **Dashboard → Settings → API** sayfasından şunları not alın:
   - `Project URL` (SUPABASE_URL)
   - `anon public` key (SUPABASE_ANON_KEY)
   - `service_role` key (SUPABASE_SERVICE_ROLE_KEY) — **güvenli yerde saklayın!**

---

## ADIM 2: Database Schema Kurulumu

1. Supabase Dashboard → **SQL Editor** → New Query
2. `supabase/schema.sql` dosyasının tüm içeriğini yapıştırın ve **Run** yapın
3. Hata yoksa devam edin

---

## ADIM 3: RLS Politikaları

1. SQL Editor → New Query
2. `supabase/rls_policies.sql` dosyasının tüm içeriğini yapıştırın ve **Run** yapın

---

## ADIM 4: Seed Data (İlk Veriler)

1. SQL Editor → New Query
2. `supabase/seed.sql` dosyasının ilk bölümünü çalıştırın (bonus_thresholds)

---

## ADIM 5: Admin Kullanıcısı Oluşturma

1. Supabase Dashboard → **Authentication → Users → Add User**
   - Email: `admin@okan.internal`
   - Password: güçlü bir şifre belirleyin
   - "Email Confirm" seçeneğini **ON** yapın
2. Kullanıcı oluşturulduktan sonra listeden UUID'yi kopyalayın
3. SQL Editor'da çalıştırın:
   ```sql
   INSERT INTO public.profiles (id, role)
   VALUES ('<KOPYALADIGINIZ_UUID>', 'admin');
   ```

---

## ADIM 6: Netlify Deploy

### 6a. GitHub'a Yükle
```bash
git init
git add .
git commit -m "Initial production deploy"
git remote add origin https://github.com/kullanici-adi/okan-surucu.git
git push -u origin main
```

### 6b. Netlify'a Bağla
1. [netlify.com](https://netlify.com) → "Add new site → Import from Git"
2. GitHub reponuzu seçin
3. Build settings:
   - Base directory: `deploy/` ← **önemli: sadece deploy klasörü**
   - Build command: (boş bırakın)
   - Publish directory: `.`

### 6c. Environment Variables Ekle
Netlify Dashboard → Site Settings → **Environment Variables** → Add a variable:

| Key | Value |
|-----|-------|
| `SUPABASE_URL` | `https://YOUR_PROJECT.supabase.co` |
| `SUPABASE_ANON_KEY` | `eyJ...` (anon key) |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJ...` (service role — sadece Functions için) |

### 6d. Deploy
- Netlify otomatik deploy eder. İlk deploy ~2 dakika sürer.
- Site URL'nizi not alın: `https://xxx.netlify.app`

---

## ADIM 7: Supabase Auth URL'lerini Güncelle

1. Supabase Dashboard → **Authentication → URL Configuration**
2. Site URL: `https://xxx.netlify.app`
3. Redirect URLs: `https://xxx.netlify.app/**`

---

## ADIM 8: Sisteme İlk Giriş ve Test

### Admin Girişi Test
- `https://xxx.netlify.app` → Yönetici Paneli
- Email: `admin@okan.internal`
- Password: ADIM 5'te belirlediğiniz şifre

### İlk Öğretmen Oluşturma
1. Admin Paneli → Öğretmenler → **Öğretmen Ekle**
2. Ad, Soyad, Sicil No ve Şifre girin
3. Sistem otomatik olarak Supabase Auth'ta kullanıcı oluşturur

### Öğretmen Girişi Test
- `https://xxx.netlify.app` → Öğretmen Paneli
- Sicil No ve belirlenen şifre ile giriş

### Kursiyer Akışı Test
1. Öğretmen Paneli → Kursiyer Ekle → TC ile kaydet
2. Sınav Sonucu Gir → Öğrenci seç → Sonuç ekle
3. `https://xxx.netlify.app` → Kursiyer Girişi → TC ile giriş
4. Anket doldur ve gönder

---

## GÜVENLİK KONTROLLERİ

- [ ] `service_role` key hiçbir HTML/JS dosyasında yok
- [ ] Tüm tablolarda RLS aktif (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`)
- [ ] Admin paneli sadece admin rolündeki kullanıcılar görebilir
- [ ] Öğretmen sadece kendi kursiyerlerini görebilir
- [ ] Kursiyer TC sorgusu sadece RPC üzerinden (security definer)
- [ ] TC numaraları admin dışında maskeli gösteriliyor
- [ ] Hiçbir kayıt hard delete edilmiyor (soft delete)

---

## VERİ GÜVENLİĞİ

- Tüm silme işlemleri `is_deleted=true, deleted_at=now()` ile yapılır
- Önemli işlemler `audit_logs` tablosuna otomatik kaydedilir
- Admin panelinden İşlem Kayıtları görüntülenebilir

---

## BAKIM

### Düzenli Yedekleme
- Supabase Dashboard → Database → **Backups** — otomatik günlük yedek (Pro plan)
- Free plan için: `pg_dump` ile manuel yedek

### Prim Hesaplama
- Her ayın sonunda Admin Paneli → Prim Hesaplama → **Hesapla** butonuna basın
- Ödenen primleri "Öde" butonuyla işaretleyin

### Öğretmen Şifre Sıfırlama
- Supabase Dashboard → Authentication → Users → kullanıcıyı bulun → Send Password Reset

---

## SORUN GİDERME

**Kursiyer TC ile giriş yapamıyor:**
→ Öğretmen panelinde kursiyer eklenmiş mi kontrol edin. TC no tam 11 hane olmalı.

**Öğretmen giriş yapamıyor:**
→ Supabase Auth → Users'da kullanıcı var mı? "Banned" durumda değil mi?

**Anket gönderilemıyor:**
→ Supabase SQL Editor: `SELECT * FROM surveys` ile veri var mı kontrol edin. RLS politikaları doğru mu?

**Netlify Function çalışmıyor:**
→ Netlify Dashboard → Functions sekmesinden hata loglarına bakın.
→ Environment Variables doğru tanımlanmış mı?
