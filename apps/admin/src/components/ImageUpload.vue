<script setup>
// Reusable image picker: shows a thumbnail, uploads the chosen file to
// POST /v1/uploads and emits the returned absolute URL. v-model = image URL.
import { ref } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { ImagePlus, X } from 'lucide-vue-next'

const props = defineProps({
  modelValue: { type: String, default: '' },
  size: { type: Number, default: 72 },
})
const emit = defineEmits(['update:modelValue'])

const input = ref(null)
const busy = ref(false)
const err = ref('')

function pick() {
  input.value?.click()
}
async function onFile(e) {
  const file = e.target.files?.[0]
  if (!file) return
  err.value = ''
  busy.value = true
  try {
    const res = await api.upload('/v1/uploads', file)
    emit('update:modelValue', res.url)
  } catch (ex) {
    err.value = ex instanceof ApiError ? ex.message : 'Yuklab bo‘lmadi'
  } finally {
    busy.value = false
    if (input.value) input.value.value = ''
  }
}
function clear() {
  emit('update:modelValue', '')
}
</script>

<template>
  <div class="img-up">
    <div class="thumb" :style="{ width: size + 'px', height: size + 'px' }" @click="pick">
      <img v-if="modelValue" :src="modelValue" alt="" />
      <span v-else class="ph"><ImagePlus :size="20" /></span>
      <span v-if="busy" class="ov">
        <span class="spinner" style="width: 18px; height: 18px; border-width: 2px"></span>
      </span>
    </div>
    <div class="img-actions">
      <button type="button" class="btn btn-sm btn-ghost" @click="pick">
        {{ modelValue ? 'O‘zgartirish' : 'Rasm yuklash' }}
      </button>
      <button v-if="modelValue" type="button" class="btn btn-sm btn-ghost del" @click="clear">
        <X :size="14" />
      </button>
    </div>
    <small v-if="err" class="err">{{ err }}</small>
    <input ref="input" type="file" accept="image/*" hidden @change="onFile" />
  </div>
</template>

<style scoped>
.img-up {
  display: flex;
  flex-direction: column;
  gap: 6px;
  align-items: flex-start;
}
.thumb {
  position: relative;
  border-radius: 10px;
  border: 1px dashed var(--border);
  background: var(--surface-2, rgba(127, 127, 127, 0.08));
  overflow: hidden;
  cursor: pointer;
  flex-shrink: 0;
}
.thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.ph {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  color: var(--text-muted);
}
.ov {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  background: rgba(0, 0, 0, 0.3);
}
.img-actions {
  display: flex;
  gap: 4px;
  align-items: center;
}
.del {
  color: var(--danger, #ef4444);
}
.err {
  color: var(--danger, #ef4444);
  font-size: 12px;
}
</style>
