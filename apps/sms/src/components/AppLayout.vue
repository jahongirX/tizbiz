<script setup>
import { ref, computed } from 'vue'
import { RouterView, RouterLink, useRoute } from 'vue-router'
import { BarChart3, Smartphone, Send, MessageSquare, LogOut, Menu } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import logoUrl from '../assets/logo.png'

const auth = useAuthStore()
const route = useRoute()
const menuOpen = ref(false)

const nav = [
  { to: '/', label: 'Statistika', icon: BarChart3 },
  { to: '/devices', label: 'Serverlar', icon: Smartphone },
  { to: '/send', label: 'Xabar Yuborish', icon: Send },
  { to: '/messages', label: 'Xabarlar', icon: MessageSquare },
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
