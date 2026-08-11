<script setup>
import { ref, computed, watch } from 'vue'
import { RouterView, RouterLink, useRoute } from 'vue-router'
import {
  CalendarDays,
  ClipboardList,
  Users,
  BarChart3,
  Settings,
  ChevronRight,
  Sun,
  Moon,
  LogOut,
  Menu,
  Gift,
} from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import { verticalFor } from '../lib/verticals'
import MiniCalendar from './MiniCalendar.vue'
import logoUrl from '../assets/logo.png'

const auth = useAuthStore()
const route = useRoute()

// The active business's vertical drives the accent colour and the terminology
// (services -> "Menyu"/"Buyumlar", staff -> "Shifokorlar", etc.).
const vertical = computed(() => verticalFor(auth.activeBusiness))
const accentSoft = computed(() => `color-mix(in srgb, ${vertical.value.accent} 14%, transparent)`)
const switching = ref(false)
const menuOpen = ref(false)

// Light/dark theme toggle. No override -> follows the OS; a manual pick is
// persisted and wins via the data-theme attribute on <html>.
const prefersDark = typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches
const theme = ref(document.documentElement.getAttribute('data-theme') || (prefersDark ? 'dark' : 'light'))
function toggleTheme() {
  theme.value = theme.value === 'dark' ? 'light' : 'dark'
  document.documentElement.setAttribute('data-theme', theme.value)
  localStorage.setItem('tizbiz_theme', theme.value)
}

// Top-level nav: direct links + collapsible groups. Kept short (YClients-style).
// Computed so the vertical's terminology + icon flow into the labels.
const nav = computed(() => {
  const t = vertical.value.terms
  return [
    { type: 'link', to: '/', label: 'Jadval', icon: CalendarDays },
    // Catalog verticals (cafe/restaurant + clinic) work in orders/requests,
    // not time-slot appointments — both use the web-catalog storefront.
    {
      type: 'link',
      to: ['catalog', 'medical'].includes(vertical.value.engine) ? '/orders' : '/appointments',
      label: t.appointments,
      icon: ClipboardList,
    },
    { type: 'link', to: '/loyalty', label: 'Loyallik', icon: Gift },
    {
      type: 'group',
      key: 'clients',
      label: 'Mijozlar',
      icon: Users,
      children: [
        { to: '/clients', label: 'Baza' },
        { to: '/categories', label: 'Kategoriyalar' },
      ],
    },
    {
      type: 'group',
      key: 'catalog',
      label: 'Katalog',
      icon: vertical.value.icon,
      children: [
        { to: '/services', label: t.services },
        { to: '/staff', label: t.staff },
        { to: '/schedule', label: 'Ish jadvali' },
        { to: '/ombor', label: 'Ombor' },
      ],
    },
    {
      type: 'group',
      key: 'reports',
      label: 'Hisobotlar',
      icon: BarChart3,
      children: [
        { to: '/dashboard', label: 'Boshqaruv' },
        { to: '/analytics', label: 'Analitika' },
        { to: '/finance', label: 'Moliya' },
        { to: '/payroll', label: 'Ish haqi' },
      ],
    },
    {
      type: 'group',
      key: 'settings',
      label: 'Sozlamalar',
      icon: Settings,
      children: [
        { to: '/team', label: 'Jamoa' },
        { to: '/settings', label: 'Onlayn-yozuv' },
      ],
    },
  ]
})

const openGroups = ref({})

function groupHasActive(group) {
  return group.children.some((c) => c.to === route.path)
}

// Auto-expand the group containing the active route (also keeps it open on nav).
watch(
  () => route.path,
  () => {
    for (const item of nav.value) {
      if (item.type === 'group' && groupHasActive(item)) {
        openGroups.value[item.key] = true
      }
    }
  },
  { immediate: true },
)

function toggleGroup(key) {
  openGroups.value[key] = !openGroups.value[key]
}
function isOpen(key) {
  return !!openGroups.value[key]
}

async function onSwitch(e) {
  const id = Number(e.target.value)
  if (!id || id === auth.active?.business_id) return
  switching.value = true
  try {
    await auth.switchBusiness(id)
  } finally {
    switching.value = false
  }
}
</script>

<template>
  <div class="shell" :style="{ '--primary': vertical.accent, '--primary-soft': accentSoft }">
    <aside class="sidebar" :class="{ open: menuOpen }">
      <div class="brand">
        <!-- The business's own logo (branding settings) when set; else the TizBiz mark. -->
        <div v-if="auth.activeBusiness?.logo" class="brand-row">
          <img :src="auth.activeBusiness.logo" :alt="auth.businessName" class="biz-logo" />
          <span class="biz-name">{{ auth.businessName }}</span>
        </div>
        <img v-else :src="logoUrl" alt="TizBiz" class="brand-logo" />
        <span class="vbadge">
          <component :is="vertical.icon" :size="12" />
          {{ vertical.short }}
        </span>
      </div>

      <div class="side-scroll">
        <MiniCalendar />

        <nav class="nav">
          <template v-for="item in nav">
            <!-- Direct link -->
            <RouterLink
              v-if="item.type === 'link'"
              :key="item.to"
              :to="item.to"
              class="nav-link"
              @click="menuOpen = false"
            >
              <span class="ic"><component :is="item.icon" :size="18" /></span>
              <span>{{ item.label }}</span>
            </RouterLink>

            <!-- Collapsible group -->
            <div v-else :key="item.key" class="nav-group">
              <button
                type="button"
                class="nav-link nav-group-head"
                :class="{ 'has-active': groupHasActive(item) }"
                :aria-expanded="isOpen(item.key)"
                @click="toggleGroup(item.key)"
              >
                <span class="ic"><component :is="item.icon" :size="18" /></span>
                <span class="grow">{{ item.label }}</span>
                <ChevronRight class="chev" :class="{ open: isOpen(item.key) }" :size="16" />
              </button>

              <div class="group-body" :class="{ open: isOpen(item.key) }">
                <div class="group-body-inner">
                  <RouterLink
                    v-for="c in item.children"
                    :key="c.to"
                    :to="c.to"
                    class="nav-sub"
                    @click="menuOpen = false"
                  >
                    {{ c.label }}
                  </RouterLink>
                </div>
              </div>
            </div>
          </template>
        </nav>
      </div>
    </aside>

    <div v-if="menuOpen" class="scrim" @click="menuOpen = false"></div>

    <div class="main">
      <header class="topbar">
        <button class="btn btn-ghost btn-sm burger" aria-label="Menyu" @click="menuOpen = !menuOpen">
          <Menu :size="20" />
        </button>
        <div class="biz">
          <select
            v-if="auth.businesses.length > 1"
            :value="auth.active?.business_id"
            :disabled="switching"
            class="biz-select"
            @change="onSwitch"
          >
            <option v-for="b in auth.businesses" :key="b.id" :value="b.id">
              {{ b.name }}
            </option>
          </select>
          <strong v-else class="biz-name">{{ auth.businessName }}</strong>
        </div>
        <div class="row" style="gap: 10px">
          <button
            class="btn btn-ghost btn-sm theme-btn"
            :aria-label="theme === 'dark' ? 'Yorug‘ rejim' : 'Qorong‘i rejim'"
            :title="theme === 'dark' ? 'Yorug‘ rejim' : 'Qorong‘i rejim'"
            @click="toggleTheme"
          >
            <Sun v-if="theme === 'dark'" :size="18" />
            <Moon v-else :size="18" />
          </button>
          <span class="muted user-name">{{ auth.user?.name }}</span>
          <button class="btn btn-sm logout-btn" @click="auth.logout()">
            <LogOut :size="16" />
            <span>Chiqish</span>
          </button>
        </div>
      </header>

      <main class="content">
        <RouterView />
      </main>
    </div>
  </div>
</template>

<style scoped>
.shell {
  display: flex;
  min-height: 100vh;
}
.sidebar {
  width: var(--sidebar-w);
  flex-shrink: 0;
  background: var(--surface);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  position: sticky;
  top: 0;
  height: 100vh;
}
.brand {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 8px;
  padding: 18px 20px;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
.brand-logo {
  height: 30px;
  width: auto;
  display: block;
}
.brand-row {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}
.biz-logo {
  width: 38px;
  height: 38px;
  flex: 0 0 auto;
  border-radius: 10px;
  object-fit: cover;
  background: var(--surface-2, rgba(127, 127, 127, 0.1));
}
.biz-name {
  font-weight: 700;
  font-size: 16px;
  line-height: 1.15;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.vbadge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 600;
  color: var(--primary);
}
.side-scroll {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 12px 10px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  /* Thin, unobtrusive scrollbar so it never eats layout width. */
  scrollbar-width: thin;
  scrollbar-color: var(--border) transparent;
  scrollbar-gutter: stable;
}
.side-scroll::-webkit-scrollbar {
  width: 6px;
}
.side-scroll::-webkit-scrollbar-track {
  background: transparent;
}
.side-scroll::-webkit-scrollbar-thumb {
  background: var(--border);
  border-radius: 3px;
}
.side-scroll:hover::-webkit-scrollbar-thumb {
  background: var(--text-muted);
}
.nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.nav-link {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 10px 12px;
  border-radius: 8px;
  color: var(--text);
  font-weight: 550;
  text-decoration: none;
  width: 100%;
}
.nav-link:hover {
  background: var(--surface-2);
  text-decoration: none;
}
.nav-link.router-link-exact-active {
  background: var(--primary-soft);
  color: var(--primary);
}
.nav-link .ic {
  width: 20px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  opacity: 0.85;
}

/* Group header is a button; reuse nav-link look. */
.nav-group-head {
  border: none;
  background: transparent;
  font: inherit;
  font-weight: 550;
  cursor: pointer;
  color: var(--text);
}
.nav-group-head.has-active {
  color: var(--primary);
}
/* Group label sits left, right after the icon (like the direct links); the
   chevron is pushed to the far right. */
.nav-group-head .grow {
  flex: 1;
  text-align: left;
}
.theme-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  line-height: 1;
}
.logout-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.chev {
  flex-shrink: 0;
  transition: transform 0.2s ease;
  opacity: 0.7;
}
.chev.open {
  transform: rotate(90deg);
}

/* Smooth collapse using grid-rows (no fixed heights needed). */
.group-body {
  display: grid;
  grid-template-rows: 0fr;
  transition: grid-template-rows 0.2s ease;
}
.group-body.open {
  grid-template-rows: 1fr;
}
.group-body-inner {
  overflow: hidden;
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin: 2px 0 4px 21px;
  padding-left: 10px;
  border-left: 1.5px solid var(--border);
}
.nav-sub {
  position: relative;
  display: block;
  padding: 8px 12px;
  border-radius: 8px;
  color: var(--text-muted);
  font-weight: 550;
  font-size: 13px;
  text-decoration: none;
  transition: background 0.12s, color 0.12s;
}
.nav-sub:hover {
  background: var(--surface-2);
  color: var(--text);
  text-decoration: none;
}
.nav-sub.router-link-exact-active {
  background: var(--primary-soft);
  color: var(--primary);
  font-weight: 650;
}
/* Accent marker on the guide line for the active sub-item. */
.nav-sub.router-link-exact-active::before {
  content: '';
  position: absolute;
  left: -11px;
  top: 50%;
  transform: translateY(-50%);
  width: 2px;
  height: 60%;
  background: var(--primary);
  border-radius: 2px;
}

.main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}
.topbar {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 12px 22px;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
  position: sticky;
  top: 0;
  z-index: 20;
}
.biz {
  flex: 1;
  min-width: 0;
}
.biz-select {
  width: auto;
  max-width: 260px;
  font-weight: 600;
}
.biz-name {
  font-size: 15px;
}
.user-name {
  font-size: 13px;
}
.content {
  padding: 24px;
  max-width: 1200px;
  width: 100%;
}
.burger {
  display: none;
  font-size: 18px;
}
.scrim {
  display: none;
}
@media (max-width: 860px) {
  .sidebar {
    position: fixed;
    left: 0;
    top: 0;
    z-index: 60;
    transform: translateX(-100%);
    transition: transform 0.2s;
  }
  .sidebar.open {
    transform: translateX(0);
  }
  .scrim {
    display: block;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    z-index: 50;
  }
  .burger {
    display: inline-flex;
  }
  .user-name {
    display: none;
  }
}
</style>
