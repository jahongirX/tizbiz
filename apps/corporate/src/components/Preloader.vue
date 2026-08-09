<script setup>
// Full-screen route preloader. Visibility is controlled by the parent via
// <Preloader v-if="isLoading" /> and a fade <transition>. Purely presentational.
</script>

<template>
  <div class="preloader" role="status" aria-live="polite" aria-label="Yuklanmoqda">
    <div class="preloader__inner">
      <div class="preloader__mark">
        <span class="preloader__ring"></span>
        <span class="preloader__letter">N</span>
      </div>
      <span class="preloader__name">TizBiz</span>
      <div class="preloader__bar" aria-hidden="true">
        <span class="preloader__fill"></span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.preloader {
  position: fixed;
  inset: 0;
  z-index: 200;
  display: grid;
  place-items: center;
  background: color-mix(in srgb, var(--bg) 92%, transparent);
  backdrop-filter: saturate(140%) blur(6px);
}
.preloader__inner {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 18px;
}
.preloader__mark {
  position: relative;
  width: 64px;
  height: 64px;
  display: grid;
  place-items: center;
}
.preloader__letter {
  position: relative;
  z-index: 1;
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  border-radius: 14px;
  background: var(--accent);
  color: #fff;
  font-weight: 800;
  font-size: 22px;
  animation: pulse 1.3s ease-in-out infinite;
}
.preloader__ring {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  border: 3px solid var(--accent-soft);
  border-top-color: var(--accent);
  animation: spin 0.9s linear infinite;
}
.preloader__name {
  font-weight: 700;
  font-size: 16px;
  letter-spacing: 0.02em;
  color: var(--text-soft);
}
.preloader__bar {
  width: 168px;
  height: 4px;
  border-radius: 999px;
  background: var(--accent-soft);
  overflow: hidden;
}
.preloader__fill {
  display: block;
  width: 40%;
  height: 100%;
  border-radius: 999px;
  background: linear-gradient(90deg, var(--accent), #7aa2ff);
  animation: slide 1.15s ease-in-out infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
@keyframes pulse {
  0%,
  100% {
    transform: scale(1);
  }
  50% {
    transform: scale(0.9);
  }
}
@keyframes slide {
  0% {
    transform: translateX(-120%);
  }
  50% {
    transform: translateX(60%);
  }
  100% {
    transform: translateX(320%);
  }
}

@media (prefers-reduced-motion: reduce) {
  .preloader__ring,
  .preloader__letter,
  .preloader__fill {
    animation-duration: 2.4s;
  }
}
</style>
