<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { Copy, Check, RefreshCw, KeyRound, Eye, EyeOff } from 'lucide-vue-next'

const loading = ref(true)
const unavailable = ref('')
const apiKey = ref('')
const baseUrl = ref('https://api.tizbiz.uz')
const reveal = ref(false)
const copied = ref('')
const regenerating = ref(false)

const masked = computed(() => {
  const k = apiKey.value
  if (!k) return ''
  return reveal.value ? k : k.slice(0, 8) + '••••••••••••••••••••••••' + k.slice(-4)
})

onMounted(load)
async function load() {
  loading.value = true
  unavailable.value = ''
  try {
    const res = await api.get('/v1/sms/apikey')
    apiKey.value = res.api_key
    baseUrl.value = res.base_url || baseUrl.value
  } catch (e) {
    unavailable.value = e instanceof ApiError ? e.message : 'API kaliti yuklanmadi'
  } finally {
    loading.value = false
  }
}

async function copy(text, tag) {
  try {
    await navigator.clipboard.writeText(text)
    copied.value = tag
    setTimeout(() => (copied.value = ''), 1500)
  } catch { /* clipboard blocked */ }
}

async function regenerate() {
  if (!confirm('Yangi API kalit yaratilsinmi?\n\nEski kalit ishlamay qoladi — uni ishlatayotgan barcha tizimlarni yangilashingiz kerak bo‘ladi.')) return
  regenerating.value = true
  try {
    const res = await api.post('/v1/sms/apikey/regenerate')
    apiKey.value = res.api_key
    reveal.value = true
  } catch (e) {
    alert(e instanceof ApiError ? e.message : 'Xatolik')
  } finally {
    regenerating.value = false
  }
}

const sendUrl = computed(() => `${baseUrl.value}/v1/sms/api/send`)
const curlExample = computed(() => `curl -X POST "${baseUrl.value}/v1/sms/api/send" \\
  -H "X-Api-Key: ${apiKey.value || 'SIZNING_KALITINGIZ'}" \\
  -H "Content-Type: application/json" \\
  -d '{"to": "+998901234567", "text": "Salom, TizBiz!"}'`)

const phpExample = computed(() => `<?php
$ch = curl_init("${baseUrl.value}/v1/sms/api/send");
curl_setopt_array($ch, [
  CURLOPT_POST => true,
  CURLOPT_RETURNTRANSFER => true,
  CURLOPT_HTTPHEADER => [
    "X-Api-Key: ${apiKey.value || 'SIZNING_KALITINGIZ'}",
    "Content-Type: application/json",
  ],
  CURLOPT_POSTFIELDS => json_encode([
    "to"   => "+998901234567",       // yoki ["+998..", "+998.."]
    "text" => "Salom, TizBiz!",
  ]),
]);
$response = json_decode(curl_exec($ch), true);
curl_close($ch);
print_r($response["data"]); // ["sent" => 1, "failed" => 0, ...]`)

const endpoints = [
  { m: 'POST', p: '/v1/sms/api/send', d: 'Bir yoki bir nechta raqamga SMS yuborish' },
  { m: 'GET', p: '/v1/sms/api/balance', d: 'Oylik limit va sarflangan miqdor' },
  { m: 'GET', p: '/v1/sms/api/messages', d: 'Yuborilgan xabarlar tarixi (status bo‘yicha filtr)' },
  { m: 'GET', p: '/v1/sms/api/messages/{id}', d: 'Bitta xabar holati' },
  { m: 'GET', p: '/v1/sms/api/devices', d: 'Ulangan serverlar (telefonlar) ro‘yxati' },
]
</script>

<template>
  <div class="page-head"><h2>API integratsiya</h2></div>

  <div v-if="loading" class="spinner"></div>

  <div v-else-if="unavailable" class="card empty">{{ unavailable }}</div>

  <template v-else>
    <!-- Key -->
    <div class="card" style="max-width: 760px">
      <div class="field" style="margin: 0">
        <label><KeyRound :size="14" style="vertical-align: -2px" /> Sizning API kalitingiz</label>
        <div class="row" style="gap: 8px; flex-wrap: nowrap">
          <input :value="masked" readonly class="mono" style="flex: 1" />
          <button class="btn ghost sm" :title="reveal ? 'Yashirish' : 'Ko‘rsatish'" @click="reveal = !reveal">
            <component :is="reveal ? EyeOff : Eye" :size="15" />
          </button>
          <button class="btn ghost sm" title="Nusxa olish" @click="copy(apiKey, 'key')">
            <component :is="copied === 'key' ? Check : Copy" :size="15" />
          </button>
        </div>
        <p class="muted" style="font-size: 12px; margin: 8px 0 0">
          Bu kalitni maxfiy saqlang. U orqali sizning nomingizdan SMS yuboriladi va limitdan hisoblanadi.
        </p>
      </div>
      <div class="row" style="justify-content: space-between; margin-top: 16px; gap: 12px">
        <span class="muted" style="font-size: 13px">Base URL: <code class="mono">{{ baseUrl }}</code></span>
        <button class="btn ghost sm" :disabled="regenerating" @click="regenerate">
          <RefreshCw :size="14" /> {{ regenerating ? '…' : 'Yangi kalit' }}
        </button>
      </div>
    </div>

    <!-- Endpoints -->
    <div class="card" style="max-width: 760px; margin-top: 18px">
      <h3 style="margin: 0 0 12px">Endpointlar</h3>
      <p class="muted" style="font-size: 13px; margin: 0 0 14px">
        Kalitni <code class="mono">X-Api-Key</code> header'da yuboring
        (yoki <code class="mono">Authorization: Bearer …</code>).
        Javob <code class="mono">{ "data": … }</code> ko‘rinishida, xatolar <code class="mono">{ "errors": [ … ] }</code>.
      </p>
      <div class="table-wrap">
        <table class="table">
          <tbody>
            <tr v-for="e in endpoints" :key="e.p">
              <td><span class="method" :class="e.m.toLowerCase()">{{ e.m }}</span></td>
              <td class="mono" style="white-space: nowrap">{{ e.p }}</td>
              <td class="muted">{{ e.d }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Examples -->
    <div class="card code-card" style="max-width: 760px; margin-top: 18px">
      <div class="row" style="justify-content: space-between; align-items: center; margin-bottom: 8px">
        <h3 style="margin: 0">Misol — cURL</h3>
        <button class="btn ghost sm" @click="copy(curlExample, 'curl')">
          <component :is="copied === 'curl' ? Check : Copy" :size="14" /> Nusxa
        </button>
      </div>
      <pre class="code"><code>{{ curlExample }}</code></pre>
    </div>

    <div class="card code-card" style="max-width: 760px; margin-top: 18px">
      <div class="row" style="justify-content: space-between; align-items: center; margin-bottom: 8px">
        <h3 style="margin: 0">Misol — PHP</h3>
        <button class="btn ghost sm" @click="copy(phpExample, 'php')">
          <component :is="copied === 'php' ? Check : Copy" :size="14" /> Nusxa
        </button>
      </div>
      <pre class="code"><code>{{ phpExample }}</code></pre>
    </div>
  </template>
</template>

<style scoped>
.mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; }
code.mono { background: rgba(127, 127, 127, 0.12); padding: 1px 6px; border-radius: 5px; }
.method { font-weight: 700; font-size: 11px; padding: 2px 7px; border-radius: 5px; letter-spacing: 0.3px; }
.method.get { background: rgba(34, 139, 230, 0.15); color: #1c7ed6; }
.method.post { background: rgba(64, 192, 87, 0.16); color: #2f9e44; }
.code-card { background: #0f1729; border-color: #1e293b; }
.code-card h3 { color: #e2e8f0; }
.code {
  margin: 0; padding: 14px 16px; border-radius: 10px;
  background: #0b1220; color: #d7e0f0; overflow-x: auto;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12.5px; line-height: 1.55;
}
</style>
