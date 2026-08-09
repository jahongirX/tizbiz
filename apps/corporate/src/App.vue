<script setup>
import { RouterView, useRoute } from 'vue-router'
import SiteNav from './components/SiteNav.vue'
import SiteFooter from './components/SiteFooter.vue'
import Preloader from './components/Preloader.vue'
import { isLoading } from './composables/useNav'

const route = useRoute()
</script>

<template>
  <div class="page">
    <!-- Route preloader: shown by router.beforeEach, hidden by afterEach -->
    <transition name="preloader">
      <Preloader v-if="isLoading" />
    </transition>

    <SiteNav />

    <router-view v-slot="{ Component }">
      <transition name="page" mode="out-in">
        <component :is="Component" :key="route.path" />
      </transition>
    </router-view>

    <SiteFooter />
  </div>
</template>

<style scoped>
.page {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
.page > :deep(main) {
  flex: 1;
}

/* Preloader fade */
.preloader-enter-active,
.preloader-leave-active {
  transition: opacity 0.35s ease;
}
.preloader-enter-from,
.preloader-leave-to {
  opacity: 0;
}

/* Page fade + subtle slide */
.page-enter-active,
.page-leave-active {
  transition: opacity 0.28s ease, transform 0.28s ease;
}
.page-enter-from {
  opacity: 0;
  transform: translateY(10px);
}
.page-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}

@media (prefers-reduced-motion: reduce) {
  .page-enter-active,
  .page-leave-active,
  .preloader-enter-active,
  .preloader-leave-active {
    transition-duration: 0.01ms;
  }
  .page-enter-from,
  .page-leave-to {
    transform: none;
  }
}
</style>
