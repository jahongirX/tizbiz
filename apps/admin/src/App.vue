<script setup>
import { RouterView } from 'vue-router'
import ConfirmDialog from './components/ConfirmDialog.vue'
</script>

<template>
  <div style="display: contents">
    <RouterView />
    <ConfirmDialog />
  </div>
</template>
