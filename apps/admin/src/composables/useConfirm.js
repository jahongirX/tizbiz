import { reactive } from 'vue'

// Module-level singleton state shared between confirm() callers and the
// globally-mounted <ConfirmDialog /> component.
const state = reactive({
  open: false,
  title: '',
  message: '',
  confirmText: 'OK',
  cancelText: 'Bekor',
  danger: false,
  _resolve: null,
})

/**
 * Open the confirmation dialog and wait for the user's choice.
 * @param {Object} options
 * @param {string} [options.title]
 * @param {string} options.message
 * @param {string} [options.confirmText='OK']
 * @param {string} [options.cancelText='Bekor']
 * @param {boolean} [options.danger=false]
 * @returns {Promise<boolean>} true on confirm, false on cancel/close
 */
export function confirm(options = {}) {
  // Resolve any previously pending dialog as cancelled before reopening.
  if (state._resolve) {
    state._resolve(false)
    state._resolve = null
  }

  state.title = options.title ?? ''
  state.message = options.message ?? ''
  state.confirmText = options.confirmText ?? 'OK'
  state.cancelText = options.cancelText ?? 'Bekor'
  state.danger = options.danger ?? false
  state.open = true

  return new Promise((resolve) => {
    state._resolve = resolve
  })
}

/** Resolve the pending promise with `result` and close the dialog. */
function settle(result) {
  if (state._resolve) {
    state._resolve(result)
    state._resolve = null
  }
  state.open = false
}

/** Called by the dialog when the confirm button is pressed. */
export function resolveConfirm() {
  settle(true)
}

/** Called by the dialog on cancel / overlay click / Escape. */
export function resolveCancel() {
  settle(false)
}

/** Access the shared reactive dialog state (used by ConfirmDialog.vue). */
export function useConfirm() {
  return state
}

export { state as confirmState }
