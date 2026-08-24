<script setup>
defineProps({
  title: { type: String, default: '' },
  wide: { type: Boolean, default: false },
})
const emit = defineEmits(['close'])
</script>

<template>
  <div class="modal-backdrop" @mousedown.self="emit('close')">
    <div class="modal" :class="{ wide }" role="dialog" aria-modal="true">
      <header class="modal-head">
        <h3 class="mb-0">{{ title }}</h3>
        <button class="btn btn-ghost btn-sm" aria-label="Yopish" @click="emit('close')">✕</button>
      </header>
      <div class="modal-body">
        <slot />
      </div>
      <footer v-if="$slots.footer" class="modal-foot">
        <slot name="footer" />
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
  align-items: flex-start;
  justify-content: center;
  padding: 40px 16px;
  z-index: 100;
  overflow-y: auto;
}
.modal {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  width: 100%;
  max-width: 480px;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.25);
  animation: pop 0.14s ease-out;
}
.modal.wide {
  max-width: 640px;
}
@keyframes pop {
  from { transform: translateY(-8px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}
.modal-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  border-bottom: 1px solid var(--border);
}
.modal-body {
  padding: 20px;
}
.modal-foot {
  padding: 14px 20px;
  border-top: 1px solid var(--border);
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

/*
 * Phone: a dialog floating in the middle wastes the screen and puts the buttons
 * wherever the content ends. Below 640px it becomes a sheet — anchored to the
 * bottom, as tall as it needs, with the actions pinned where a thumb reaches.
 */
@media (max-width: 640px) {
  .modal-backdrop {
    padding: 0;
    align-items: flex-end;
  }
  .modal,
  .modal.wide {
    max-width: 100%;
    max-height: 92vh;
    display: flex;
    flex-direction: column;
    border-radius: 16px 16px 0 0;
    border-bottom: 0;
    animation: sheet 0.18s ease-out;
  }
  .modal-head {
    position: sticky;
    top: 0;
    z-index: 1;
    background: var(--surface);
  }
  .modal-body {
    overflow-y: auto;
    padding: 16px;
  }
  .modal-foot {
    position: sticky;
    bottom: 0;
    background: var(--surface);
    padding-bottom: max(14px, env(safe-area-inset-bottom));
  }
  .modal-foot .btn {
    flex: 1;
  }
}
@keyframes sheet {
  from { transform: translateY(14px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}
</style>
