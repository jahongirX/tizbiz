<script setup>
import { computed } from 'vue'
import { RouterView, RouterLink, useRoute } from 'vue-router'
import { Users, LogOut } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import logoUrl from '../assets/logo.png'

const auth = useAuthStore()
const route = useRoute()

const nav = [{ to: '/', label: 'SMS Akkauntlar', icon: Users }]
const title = computed(() => nav.find((n) => n.to === route.path)?.label || 'Superadmin')
</script>

<template>
  <div class="shell">
    <aside class="sidebar">
      <div class="brand">
        <img :src="logoUrl" alt="TizBiz" />
        <span class="tag">Admin</span>
      </div>
      <nav class="nav">
        <RouterLink v-for="item in nav" :key="item.to" :to="item.to">
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
        <div class="row"><h1>{{ title }}</h1></div>
      </div>
      <div class="content">
        <RouterView />
      </div>
    </div>
  </div>
</template>
