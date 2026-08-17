<script setup>
import { ref, onMounted } from 'vue'
import { api } from '@tizbiz/api-client'

const loading = ref(true)
const s = ref(null)

onMounted(async () => {
  try {
    s.value = await api.get('/v1/sms/stats')
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="page-head"><h2>Statistika</h2></div>

  <div v-if="loading" class="spinner"></div>

  <template v-else-if="s">
    <div class="grid stat-grid" style="margin-bottom: 16px">
      <div class="card stat"><span class="k">Jami xabar</span><span class="v">{{ s.messages.total }}</span></div>
      <div class="card stat"><span class="k">Yuborilgan</span><span class="v ok">{{ s.messages.sent }}</span></div>
      <div class="card stat"><span class="k">Xato</span><span class="v bad">{{ s.messages.failed }}</span></div>
      <div class="card stat"><span class="k">Kutilmoqda</span><span class="v warn">{{ s.messages.pending }}</span></div>
      <div class="card stat"><span class="k">Bugun</span><span class="v">{{ s.messages.today }}</span></div>
    </div>

    <div class="grid stat-grid">
      <div class="card stat"><span class="k">Serverlar</span><span class="v">{{ s.devices.total }}</span></div>
      <div class="card stat"><span class="k">Faol</span><span class="v ok">{{ s.devices.active }}</span></div>
      <div class="card stat"><span class="k">Online</span><span class="v">{{ s.devices.online }}</span></div>
    </div>
  </template>
</template>
