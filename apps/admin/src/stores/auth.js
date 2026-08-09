import { defineStore } from 'pinia'
import { api, auth } from '@tizbiz/api-client'
import router from '../router'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    businesses: [],
    active: null,
  }),

  getters: {
    isAuthed: () => auth.isAuthed,
    activeBusiness(state) {
      if (!state.active) return null
      return (
        state.businesses.find((b) => b.id === state.active.business_id) || null
      )
    },
    businessName() {
      return this.activeBusiness?.name || 'TizBiz'
    },
    role(state) {
      return state.active?.role || null
    },
  },

  actions: {
    _apply(res) {
      if (res.token) auth.set(res.token)
      if (res.user !== undefined) this.user = res.user
      if (res.businesses !== undefined) this.businesses = res.businesses
      if (res.active !== undefined) this.active = res.active
    },

    async login(phone, password) {
      const res = await api.post('/v1/auth/login', { phone, password })
      this._apply(res)
      return res
    },

    async register(payload) {
      const res = await api.post('/v1/auth/register', payload)
      // register returns {token,user,business}; normalize into businesses/active
      auth.set(res.token)
      this.user = res.user
      if (res.business) {
        this.businesses = [res.business]
        this.active = {
          business_id: res.business.id,
          role: res.business.role || 'business_owner',
        }
      }
      return res
    },

    async fetchMe() {
      const res = await api.get('/v1/auth/me')
      this.user = res.user ?? this.user
      this.businesses = res.businesses ?? this.businesses
      this.active = res.active ?? this.active
      return res
    },

    async switchBusiness(businessId) {
      const res = await api.post('/v1/auth/switch/' + businessId)
      if (res.token) auth.set(res.token)
      if (res.active) this.active = res.active
      // Refresh full context after switching tenant.
      try {
        await this.fetchMe()
      } catch (_) {
        /* ignore */
      }
      return res
    },

    logout(redirect = true) {
      auth.clear()
      this.user = null
      this.businesses = []
      this.active = null
      if (redirect) router.push('/login')
    },
  },
})
