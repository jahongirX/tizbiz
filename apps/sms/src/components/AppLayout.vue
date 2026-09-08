<script setup>
import { ref, computed } from 'vue'
import { RouterView, RouterLink, useRoute } from 'vue-router'
import { BarChart3, Smartphone, Send, MessageSquare, FileText, Users, Ban, Code2, LogOut, Menu } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import logoUrl from '../assets/logo.png'

const auth = useAuthStore()
const route = useRoute()
const menuOpen = ref(false)

const nav = [
  { to: '/panel/stats', label: 'Statistika', icon: BarChart3 },
  { to: '/panel/devices', label: 'Serverlar', icon: Smartphone },
  { to: '/panel/send', label: 'Xabar Yuborish', icon: Send },
  { to: '/panel/messages', label: 'Xabarlar', icon: MessageSquare },
  { to: '/panel/templates', label: 'Shablonlar', icon: FileText },
  { to: '/panel/contacts', label: 'Kontaktlar', icon: Users },
  { to: '/panel/blacklist', label: 'Qora ro‘yxat', icon: Ban },
  { to: '/panel/api', label: 'API', icon: Code2 },
]

const title = computed(() => nav.find((n) => n.to === route.path)?.label || 'SMS')
</script>

<template>
  <div class="shell">
    <aside class="sidebar" :class="{ open: menuOpen }">
      <div class="brand">
        <img :src="logoUrl" alt="TizBiz" />
        <span class="tag">SMS</span>
      </div>
      <nav class="nav">
        <RouterLink
          v-for="item in nav"
          :key="item.to"
          :to="item.to"
          @click="menuOpen = false"
        >
          <component :is="item.icon" :size="18" />
          <span>{{ item.label }}</span>
        </RouterLink>
      </nav>
      <div class="side-foot">
        <div class="side-user">{{ auth.userName }}</div>
        <button class="btn ghost sm" style="width: 100%" @click="auth.logout()">
          <LogOut :size="15" /> Chiqish
        </button>
      </div>
    </aside>

    <div class="main">
      <div class="topbar">
        <div class="row">
          <button class="btn ghost sm" style="display: none" @click="menuOpen = !menuOpen"><Menu :size="16" /></button>
          <h1>{{ title }}</h1>
        </div>
      </div>
      <div class="content">
        <RouterView />
      </div>
    </div>
  </div>
</template>
