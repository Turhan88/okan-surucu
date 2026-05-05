'use strict';

// Initialized after config.js is loaded (served by Netlify Function)
let supabase = null;

function initSupabase() {
  const cfg = window.APP_CONFIG || {};
  if (!cfg.SUPABASE_URL || !cfg.SUPABASE_ANON_KEY) {
    console.error('Supabase config eksik. /.netlify/functions/config kontrol edin.');
    return;
  }
  supabase = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
    auth: {
      autoRefreshToken: true,
      persistSession:   true,
      detectSessionInUrl: false
    }
  });
}

// Mask TC: 123****89
function maskTc(tc) {
  if (!tc || tc.length < 5) return tc || '';
  return tc.substring(0, 3) + '*****' + tc.substring(tc.length - 2);
}

// Format date: 2024-05-15 → 15.05.2024
function fmtDate(d) {
  if (!d) return '-';
  return new Date(d).toLocaleDateString('tr-TR', { day:'2-digit', month:'2-digit', year:'numeric' });
}

function fmtDateTime(d) {
  if (!d) return '-';
  return new Date(d).toLocaleString('tr-TR', { day:'2-digit', month:'2-digit', year:'numeric', hour:'2-digit', minute:'2-digit' });
}

function currentMonth() {
  const n = new Date();
  return `${n.getFullYear()}-${String(n.getMonth()+1).padStart(2,'0')}`;
}

function examBadge(result) {
  const map = { passed:'badge-green', failed:'badge-red', sick:'badge-orange', 'not-taken':'badge-gray' };
  const lbl = { passed:'Geçti ✓',    failed:'Kaldı ✗',  sick:'Raporlu',     'not-taken':'Girmedi' };
  return `<span class="badge ${map[result]||'badge-gray'}">${lbl[result]||result}</span>`;
}

function primBadge(amount) {
  if (amount >= 5000) return `<span class="badge prim-5000">5.000 ₺</span>`;
  if (amount >= 4000) return `<span class="badge prim-4000">4.000 ₺</span>`;
  if (amount >= 3000) return `<span class="badge prim-3000">3.000 ₺</span>`;
  if (amount >= 1000) return `<span class="badge prim-1000">1.000 ₺</span>`;
  return `<span class="badge prim-0">Prim Yok</span>`;
}

function showToast(msg, type = 'success') {
  const existing = document.getElementById('okan-toast');
  if (existing) existing.remove();
  const t = document.createElement('div');
  t.id = 'okan-toast';
  const bg = type === 'success' ? '#155724' : type === 'error' ? '#721c24' : '#004085';
  t.style.cssText = `position:fixed;bottom:24px;right:24px;z-index:9999;padding:14px 22px;border-radius:10px;background:${bg};color:white;font-size:14px;font-weight:600;box-shadow:0 6px 20px rgba(0,0,0,0.25);animation:fadeIn 0.3s ease;max-width:350px`;
  t.innerHTML = `<i class="fas fa-${type==='success'?'check-circle':'exclamation-triangle'} me-2"></i>${msg}`;
  document.body.appendChild(t);
  setTimeout(() => t.style.opacity = '0', 3000);
  setTimeout(() => t.remove(), 3500);
}

// Export data to CSV
function exportCsv(rows, filename) {
  const csv = rows.map(r => r.map(c => `"${String(c||'').replace(/"/g,'""')}"`).join(',')).join('\n');
  const blob = new Blob(['﻿'+csv], { type: 'text/csv;charset=utf-8;' });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href = url; a.download = filename; a.click();
  URL.revokeObjectURL(url);
}
