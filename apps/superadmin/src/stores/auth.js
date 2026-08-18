import { defineStore } from 'pinia'
import { api, auth } from '@tizbiz/api-client'
import router from '../router'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
  }),

  getters: {
    isAuthed: () => auth.isAuthed,
    isSuperadmin: (state) => !!state.user?.is_superadmin,
    userName(state) {
      return state.user?.name || state.user?.phone || 'Admin'
    },
  },

  actions: {
    async login(phone, password) {
      const res = await api.post('/v1/auth/login', { phone, password })
      if (res.token) auth.set(res.token)
      this.user = res.user ?? null
      return res
    },

    async fetchMe() {
      const res = await api.get('/v1/auth/me')
      this.user = res.user ?? this.user
      return res
    },

    logout(redirect = true) {
      auth.clear()
      this.user = null
      if (redirect) router.push('/login')
    },
  },
})
