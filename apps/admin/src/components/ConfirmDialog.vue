<script setup>
import { ref, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { AlertTriangle } from 'lucide-vue-next'
import { useConfirm, resolveConfirm, resolveCancel } from '../composables/useConfirm'

const state = useConfirm()
const confirmBtn = ref(null)

function onConfirm() {
  resolveConfirm()
}
function onCancel() {
  resolveCancel()
}

function onKeydown(e) {
  if (!state.open) return
  if (e.key === 'Escape') {
    e.preventDefault()
    onCancel()
  }
}

// Focus the confirm button whenever the dialog opens.
watch(
  () => state.open,
  async (open) => {
    if (open) {
      await nextTick()
      confirmBtn.value?.focus()
    }
  }
)

onMounted(() => window.addEventListener('keydown', onKeydown))
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown))
</script>

<template>
  <div v-if="state.open" class="modal-backdrop" @mousedown.self="onCancel">
    <div
      class="modal confirm-card"
      role="dialog"
      aria-modal="true"
      :aria-label="state.title || state.message"
    >
      <div class="confirm-body">
        <span class="confirm-icon" :class="{ danger: state.danger }" aria-hidden="true">
          <AlertTriangle :size="22" />
        </span>
        <div class="confirm-text">
          <h3 v-if="state.title" class="confirm-title mb-0">{{ state.title }}</h3>
          <p class="confirm-message">{{ state.message }}</p>
        </div>
      </div>
      <footer class="modal-foot">
        <button class="btn" @click="onCancel">{{ state.cancelText }}</button>
        <button
          ref="confirmBtn"
          class="btn"
          :class="state.danger ? 'btn-danger' : 'btn-primary'"
          @click="onConfirm"
        >
          {{ state.confirmText }}
        </button>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.modal-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px 16px;
  z-index: 200;
  overflow-y: auto;
}
.modal {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  width: 100%;
  max-width: 420px;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.25);
  animation: pop 0.14s ease-out;
}
@keyframes pop {
  from { transform: translateY(-8px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}
.confirm-body {
  display: flex;
  gap: 14px;
  padding: 22px 20px 6px;
}
.confirm-icon {
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: var(--primary-soft);
  color: var(--primary);
}
.confirm-icon.danger {
  background: var(--danger-soft);
  color: var(--danger);
}
.confirm-text {
  min-width: 0;
}
.confirm-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--text);
  margin-bottom: 4px;
}
.confirm-message {
  margin: 0;
  color: var(--text-muted);
  line-height: 1.5;
}
.modal-foot {
  padding: 14px 20px 18px;
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}
</style>
