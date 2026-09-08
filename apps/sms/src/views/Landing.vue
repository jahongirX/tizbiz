<script setup>
import { RouterLink } from 'vue-router'
import logoUrl from '../assets/logo.png'
import {
  Send, Smartphone, ShieldCheck, Code2, Globe, Layers,
  Check, ArrowRight, MessageSquare, Phone,
} from 'lucide-vue-next'

const stats = [
  { v: '99%', l: 'telefonlarga yetib boradi' },
  { v: '87%', l: "SMS o'qilish darajasi" },
  { v: '3–5s', l: 'yetkazish tezligi' },
]

const features = [
  { icon: Smartphone, t: "O'z telefoningiz", d: "SMS o'zingizning SIM-kartangizdan ketadi — qisqa raqam, shartnoma, yuridik shaxs shart emas." },
  { icon: Globe, t: 'Web + Android', d: 'Brauzerdan boshqaring, Android ilova orqali yuboring. Bir tap bilan telefon ulanadi.' },
  { icon: Send, t: 'Ommaviy yuborish', d: 'Minglab raqamga bir vaqtda. Kontaktlar, kategoriyalar, shablonlar va import/export.' },
  { icon: Code2, t: 'API integratsiya', d: "O'z tizimingizdan (CRM, sayt, bot) REST API orqali avtomatik SMS yuboring." },
  { icon: ShieldCheck, t: 'Xavfsiz & mustaqil', d: "Barchasi o'z serveringizda. Qora ro'yxat, cheklovlar, ish soatlari nazorati." },
  { icon: Layers, t: 'Statistika & hisobot', d: 'Yuborilgan, yetkazilgan, xato — hammasi jonli hisobotda. Nima ishlayotganini ko\'ring.' },
]

const steps = [
  { n: '1', t: "Ro'yxatdan o'ting", d: 'Tarifni tanlang va akkaunt oching — bir necha daqiqada.' },
  { n: '2', t: 'Telefonni ulang', d: 'TizBiz SMS ilovasini o‘rnating, "Start" bosing — panelda avtomat paydo bo‘ladi.' },
  { n: '3', t: 'Yuborishni boshlang', d: 'Raqamlarni tanlang, matn yozing, yuboring. Yoki API orqali ulang.' },
]

const plans = [
  {
    name: 'Start',
    daily: '30 000',
    devices: '2',
    old: '490 000',
    price: '290 000',
    highlight: false,
    perks: ['30 000 SMS / kun', '2 ta telefon (server)', 'Web + Android', 'Shablonlar & kontaktlar', 'Import / Export', 'API kirish'],
  },
  {
    name: 'Pro',
    daily: '75 000',
    devices: '5',
    old: '990 000',
    price: '590 000',
    highlight: true,
    perks: ['75 000 SMS / kun', '5 ta telefon (server)', 'Kontakt kategoriyalari', 'Jonli statistika', 'Qora ro‘yxat & cheklovlar', 'Ustuvor qo‘llab-quvvatlash'],
  },
  {
    name: 'Expert',
    daily: '150 000',
    devices: '10',
    old: '1 690 000',
    price: '990 000',
    highlight: false,
    perks: ['150 000 SMS / kun', '10 ta telefon (server)', 'Cheksiz shablon', 'To‘liq API + webhook', 'Maxsus sozlash', 'Shaxsiy menejer'],
  },
]
</script>

<template>
  <div class="lp">
    <!-- Header -->
    <header class="lp-head">
      <div class="lp-wrap lp-head-in">
        <div class="lp-brand"><img :src="logoUrl" alt="TizBiz" /><span>SMS</span></div>
        <nav class="lp-nav">
          <a href="#features">Imkoniyatlar</a>
          <a href="#how">Qanday ishlaydi</a>
          <a href="#pricing">Narxlar</a>
        </nav>
        <RouterLink to="/login" class="lp-btn lp-btn-solid sm">Kirish</RouterLink>
      </div>
    </header>

    <!-- Hero -->
    <section class="lp-hero">
      <div class="lp-wrap lp-hero-in">
        <div class="lp-badge">🇺🇿 O‘zbekiston bizneslari uchun</div>
        <h1>Minglab SMS — <span>bitta platformadan</span></h1>
        <p class="lp-sub">
          Mijozlaringizga reklama, eslatma va xabarlarni o‘z telefoningiz orqali yuboring.
          Qisqa raqam, shartnoma va yuridik shaxs shart emas.
        </p>
        <div class="lp-cta">
          <RouterLink to="/login" class="lp-btn lp-btn-solid">Boshlash <ArrowRight :size="17" /></RouterLink>
          <a href="#pricing" class="lp-btn lp-btn-ghost">Tariflarni ko‘rish</a>
        </div>
        <div class="lp-stats">
          <div v-for="s in stats" :key="s.l" class="lp-stat">
            <div class="v">{{ s.v }}</div><div class="l">{{ s.l }}</div>
          </div>
        </div>
      </div>
    </section>

    <!-- Features -->
    <section id="features" class="lp-sec">
      <div class="lp-wrap">
        <h2 class="lp-h2">Nima uchun TizBiz SMS?</h2>
        <div class="lp-grid">
          <div v-for="f in features" :key="f.t" class="lp-card">
            <div class="lp-ic"><component :is="f.icon" :size="20" /></div>
            <h3>{{ f.t }}</h3>
            <p>{{ f.d }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- How it works -->
    <section id="how" class="lp-sec lp-alt">
      <div class="lp-wrap">
        <h2 class="lp-h2">Uch qadamda</h2>
        <div class="lp-steps">
          <div v-for="s in steps" :key="s.n" class="lp-step">
            <div class="lp-step-n">{{ s.n }}</div>
            <h3>{{ s.t }}</h3>
            <p>{{ s.d }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- Pricing -->
    <section id="pricing" class="lp-sec">
      <div class="lp-wrap">
        <h2 class="lp-h2">Yillik tariflar</h2>
        <p class="lp-h2-sub">Faqat yillik obuna — bozordan <b>40% gacha arzon</b>. Kunlik SMS limiti bilan.</p>
        <div class="lp-plans">
          <div v-for="p in plans" :key="p.name" class="lp-plan" :class="{ hot: p.highlight }">
            <div v-if="p.highlight" class="lp-plan-tag">Eng ommabop</div>
            <h3 class="lp-plan-name">{{ p.name }}</h3>
            <div class="lp-plan-daily">{{ p.daily }} <span>SMS / kun</span></div>
            <div class="lp-price">
              <span class="old">{{ p.old }}</span>
              <div class="now">{{ p.price }} <span>so‘m/yil</span></div>
            </div>
            <ul class="lp-perks">
              <li v-for="perk in p.perks" :key="perk"><Check :size="15" /> {{ perk }}</li>
            </ul>
            <RouterLink to="/login" class="lp-btn" :class="p.highlight ? 'lp-btn-solid' : 'lp-btn-ghost'" style="width: 100%; justify-content: center">
              Tanlash
            </RouterLink>
          </div>
        </div>
        <p class="lp-note">Barcha tariflarda: Web panel, Android ilova, API, shablon, kontakt, qora ro‘yxat. Narxlar QQSsiz.</p>
      </div>
    </section>

    <!-- CTA -->
    <section class="lp-band">
      <div class="lp-wrap lp-band-in">
        <div>
          <h2>Bugun boshlang</h2>
          <p>Telefoningizni ulang va birinchi SMS’ni bir necha daqiqada yuboring.</p>
        </div>
        <RouterLink to="/login" class="lp-btn lp-btn-solid">Kirish <ArrowRight :size="17" /></RouterLink>
      </div>
    </section>

    <!-- Footer -->
    <footer class="lp-foot">
      <div class="lp-wrap lp-foot-in">
        <div class="lp-brand"><img :src="logoUrl" alt="TizBiz" /><span>SMS</span></div>
        <div class="lp-foot-links">
          <a href="https://t.me/tizbiz" target="_blank" rel="noopener"><MessageSquare :size="15" /> Telegram</a>
          <a href="tel:+998911631236"><Phone :size="15" /> +998 91 163 12 36</a>
        </div>
        <div class="lp-copy">© 2026 TizBiz</div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.lp {
  --lp-bg: #0b1220;
  --lp-bg2: #0e1626;
  --lp-card: #111c30;
  --lp-line: #1f2b44;
  --lp-txt: #e8eefb;
  --lp-mut: #93a1bd;
  --lp-brand: #2d7eec;
  --lp-brand2: #6fa8f5;
  background: var(--lp-bg);
  color: var(--lp-txt);
  min-height: 100vh;
  font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  line-height: 1.55;
}
.lp-wrap { max-width: 1080px; margin: 0 auto; padding: 0 20px; }

/* header */
.lp-head { position: sticky; top: 0; z-index: 20; background: rgba(11, 18, 32, 0.85); backdrop-filter: blur(10px); border-bottom: 1px solid var(--lp-line); }
.lp-head-in { display: flex; align-items: center; gap: 20px; height: 62px; }
.lp-brand { display: flex; align-items: center; gap: 8px; font-weight: 800; }
.lp-brand img { height: 26px; }
.lp-brand span { color: var(--lp-brand2); }
.lp-nav { display: flex; gap: 22px; margin-left: auto; }
.lp-nav a { color: var(--lp-mut); text-decoration: none; font-size: 14px; font-weight: 500; }
.lp-nav a:hover { color: var(--lp-txt); }

/* buttons */
.lp-btn { display: inline-flex; align-items: center; gap: 7px; border-radius: 11px; padding: 12px 20px; font-weight: 700; font-size: 15px; text-decoration: none; cursor: pointer; border: 1px solid transparent; transition: transform .06s, background .15s; }
.lp-btn.sm { padding: 8px 16px; font-size: 14px; }
.lp-btn:active { transform: translateY(1px); }
.lp-btn-solid { background: var(--lp-brand); color: #fff; }
.lp-btn-solid:hover { background: #2570d8; }
.lp-btn-ghost { background: transparent; color: var(--lp-txt); border-color: var(--lp-line); }
.lp-btn-ghost:hover { border-color: var(--lp-brand2); }

/* hero */
.lp-hero { background: radial-gradient(1000px 420px at 50% -80px, rgba(45, 126, 236, 0.28), transparent 70%), var(--lp-bg); border-bottom: 1px solid var(--lp-line); }
.lp-hero-in { text-align: center; padding: 70px 20px 64px; }
.lp-badge { display: inline-block; padding: 6px 14px; border-radius: 999px; background: rgba(45, 126, 236, 0.14); color: var(--lp-brand2); font-size: 13px; font-weight: 600; margin-bottom: 20px; }
.lp-hero h1 { font-size: clamp(32px, 6vw, 54px); line-height: 1.08; margin: 0 0 16px; font-weight: 800; letter-spacing: -0.02em; }
.lp-hero h1 span { color: var(--lp-brand2); }
.lp-sub { max-width: 620px; margin: 0 auto 28px; color: var(--lp-mut); font-size: 17px; }
.lp-cta { display: flex; gap: 12px; justify-content: center; flex-wrap: wrap; }
.lp-stats { display: flex; gap: 40px; justify-content: center; flex-wrap: wrap; margin-top: 48px; }
.lp-stat .v { font-size: 30px; font-weight: 800; color: #fff; }
.lp-stat .l { color: var(--lp-mut); font-size: 13px; }

/* sections */
.lp-sec { padding: 66px 0; }
.lp-alt { background: var(--lp-bg2); border-block: 1px solid var(--lp-line); }
.lp-h2 { text-align: center; font-size: clamp(24px, 4vw, 34px); font-weight: 800; margin: 0 0 8px; letter-spacing: -0.01em; }
.lp-h2-sub { text-align: center; color: var(--lp-mut); margin: 0 0 36px; }
.lp-h2-sub b { color: var(--lp-brand2); }

/* features */
.lp-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 18px; margin-top: 34px; }
.lp-card { background: var(--lp-card); border: 1px solid var(--lp-line); border-radius: 16px; padding: 24px; }
.lp-ic { width: 42px; height: 42px; border-radius: 11px; display: grid; place-items: center; background: rgba(45, 126, 236, 0.15); color: var(--lp-brand2); margin-bottom: 14px; }
.lp-card h3 { margin: 0 0 6px; font-size: 17px; }
.lp-card p { margin: 0; color: var(--lp-mut); font-size: 14px; }

/* steps */
.lp-steps { display: grid; grid-template-columns: repeat(3, 1fr); gap: 18px; }
.lp-step { text-align: center; padding: 10px; }
.lp-step-n { width: 46px; height: 46px; border-radius: 50%; background: var(--lp-brand); color: #fff; font-weight: 800; font-size: 20px; display: grid; place-items: center; margin: 0 auto 14px; }
.lp-step h3 { margin: 0 0 6px; font-size: 18px; }
.lp-step p { margin: 0; color: var(--lp-mut); font-size: 14px; }

/* pricing */
.lp-plans { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; align-items: start; }
.lp-plan { position: relative; background: var(--lp-card); border: 1px solid var(--lp-line); border-radius: 18px; padding: 28px 24px; }
.lp-plan.hot { border-color: var(--lp-brand); box-shadow: 0 0 0 1px var(--lp-brand), 0 20px 50px -20px rgba(45, 126, 236, 0.6); transform: translateY(-6px); }
.lp-plan-tag { position: absolute; top: -12px; left: 50%; transform: translateX(-50%); background: var(--lp-brand); color: #fff; font-size: 12px; font-weight: 700; padding: 5px 14px; border-radius: 999px; white-space: nowrap; }
.lp-plan-name { margin: 0 0 6px; font-size: 22px; font-weight: 800; }
.lp-plan-daily { color: var(--lp-brand2); font-weight: 700; font-size: 18px; margin-bottom: 16px; }
.lp-plan-daily span { color: var(--lp-mut); font-weight: 500; font-size: 14px; }
.lp-price { margin-bottom: 20px; }
.lp-price .old { color: var(--lp-mut); text-decoration: line-through; font-size: 15px; }
.lp-price .now { font-size: 30px; font-weight: 800; color: #fff; }
.lp-price .now span { font-size: 15px; color: var(--lp-mut); font-weight: 500; }
.lp-perks { list-style: none; padding: 0; margin: 0 0 24px; }
.lp-perks li { display: flex; align-items: center; gap: 9px; padding: 7px 0; font-size: 14px; color: var(--lp-txt); border-bottom: 1px solid var(--lp-line); }
.lp-perks li:last-child { border-bottom: 0; }
.lp-perks svg { color: var(--lp-brand2); flex: none; }
.lp-note { text-align: center; color: var(--lp-mut); font-size: 13px; margin-top: 28px; }

/* CTA band */
.lp-band { background: linear-gradient(90deg, #1a4fa0, #2d7eec); }
.lp-band-in { display: flex; align-items: center; justify-content: space-between; gap: 24px; padding: 40px 20px; flex-wrap: wrap; }
.lp-band h2 { margin: 0 0 4px; font-size: 26px; }
.lp-band p { margin: 0; color: rgba(255, 255, 255, 0.85); }
.lp-band .lp-btn-solid { background: #fff; color: #14203a; }
.lp-band .lp-btn-solid:hover { background: #eaf2ff; }

/* footer */
.lp-foot { border-top: 1px solid var(--lp-line); background: var(--lp-bg2); }
.lp-foot-in { display: flex; align-items: center; gap: 18px; padding: 26px 20px; flex-wrap: wrap; }
.lp-foot-links { display: flex; gap: 20px; margin-left: auto; }
.lp-foot-links a { color: var(--lp-mut); text-decoration: none; font-size: 14px; display: inline-flex; align-items: center; gap: 6px; }
.lp-foot-links a:hover { color: var(--lp-txt); }
.lp-copy { color: var(--lp-mut); font-size: 13px; }

@media (max-width: 860px) {
  .lp-grid, .lp-steps, .lp-plans { grid-template-columns: 1fr; }
  .lp-nav { display: none; }
  .lp-plan.hot { transform: none; }
  .lp-foot-links { margin-left: 0; }
}
</style>
