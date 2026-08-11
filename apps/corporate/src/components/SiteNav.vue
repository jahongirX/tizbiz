<script setup>
import { ref, onMounted, onBeforeUnmount, watch } from 'vue'
import { useRoute } from 'vue-router'
import logoUrl from '../assets/logo.png'

const LOGIN_URL = 'https://b.startup/'
const REGISTER_URL = 'https://b.startup/app/register'

const route = useRoute()
const scrolled = ref(false)
const menuOpen = ref(false)

function onScroll() {
  scrolled.value = window.scrollY > 8
}
onMounted(() => window.addEventListener('scroll', onScroll, { passive: true }))
onBeforeUnmount(() => window.removeEventListener('scroll', onScroll))

function closeMenu() {
  menuOpen.value = false
}

// Close the mobile menu whenever the route changes.
watch(() => route.fullPath, closeMenu)
</script>

<template>
  <header class="nav" :class="{ 'nav--scrolled': scrolled }">
    <div class="container nav__inner">
      <router-link to="/" class="brand" @click="closeMenu" aria-label="TizBiz — bosh sahifa">
        <img :src="logoUrl" alt="TizBiz" class="brand__logo" />
      </router-link>

      <nav class="nav__links" :class="{ 'nav__links--open': menuOpen }" aria-label="Asosiy menyu">
        <router-link to="/" @click="closeMenu">Bosh sahifa</router-link>
        <router-link to="/how-it-works" @click="closeMenu">Qanday ishlaydi</router-link>
        <router-link to="/blog" @click="closeMenu">Blog</router-link>
        <router-link to="/about" @click="closeMenu">Loyiha haqida</router-link>
        <router-link :to="{ path: '/', hash: '#pricing' }" @click="closeMenu">Narxlar</router-link>
        <a class="nav__login" :href="LOGIN_URL">Kirish</a>
        <a class="btn btn-primary nav__cta" :href="REGISTER_URL">Boshlash</a>
      </nav>

      <button
        class="nav__burger"
        :aria-expanded="menuOpen"
        aria-label="Menyu"
        @click="menuOpen = !menuOpen"
      >
        <span :class="{ open: menuOpen }"></span>
      </button>
    </div>
  </header>
</template>

<style scoped>
.nav {
  position: sticky;
  top: 0;
  z-index: 50;
  background: color-mix(in srgb, var(--bg) 82%, transparent);
  backdrop-filter: saturate(160%) blur(12px);
  border-bottom: 1px solid transparent;
  transition: border-color 0.2s ease, background 0.2s ease;
}
.nav--scrolled {
  border-bottom-color: var(--border);
}
.nav__inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 64px;
}
.brand {
  display: inline-flex;
  align-items: center;
}
.brand__logo {
  height: 34px;
  width: auto;
  display: block;
}
.nav__links {
  display: flex;
  align-items: center;
  gap: 24px;
}
.nav__links > a:not(.btn):not(.nav__login) {
  color: var(--text-soft);
  font-weight: 500;
  font-size: 15px;
}
.nav__links > a:not(.btn):hover,
.nav__links > a.router-link-active:not(.btn):not(.nav__login) {
  color: var(--text);
}
.nav__login {
  font-weight: 600;
  font-size: 15px;
}
.nav__burger {
  display: none;
  width: 42px;
  height: 42px;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: transparent;
  cursor: pointer;
  position: relative;
}
.nav__burger span,
.nav__burger span::before,
.nav__burger span::after {
  content: '';
  position: absolute;
  left: 50%;
  top: 50%;
  width: 18px;
  height: 2px;
  background: var(--text);
  transform: translate(-50%, -50%);
  transition: transform 0.2s ease, opacity 0.2s ease;
}
.nav__burger span::before {
  transform: translate(-50%, -8px);
}
.nav__burger span::after {
  transform: translate(-50%, 6px);
}
.nav__burger span.open {
  background: transparent;
}
.nav__burger span.open::before {
  transform: translate(-50%, -50%) rotate(45deg);
}
.nav__burger span.open::after {
  transform: translate(-50%, -50%) rotate(-45deg);
}

@media (max-width: 860px) {
  .nav__burger {
    display: block;
  }
  .nav__links {
    position: absolute;
    top: 64px;
    left: 0;
    right: 0;
    flex-direction: column;
    align-items: stretch;
    gap: 4px;
    padding: 16px 20px 24px;
    background: var(--bg);
    border-bottom: 1px solid var(--border);
    box-shadow: var(--shadow);
    transform: translateY(-12px);
    opacity: 0;
    pointer-events: none;
    transition: opacity 0.18s ease, transform 0.18s ease;
  }
  .nav__links--open {
    transform: translateY(0);
    opacity: 1;
    pointer-events: auto;
  }
  .nav__links > a:not(.btn) {
    padding: 10px 4px;
  }
  .nav__cta {
    margin-top: 8px;
  }
}
</style>
