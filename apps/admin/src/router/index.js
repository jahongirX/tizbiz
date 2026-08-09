import { createRouter, createWebHistory } from 'vue-router'
import { auth } from '@tizbiz/api-client'

import AppLayout from '../components/AppLayout.vue'

const routes = [
  { path: '/login', name: 'login', component: () => import('../views/Login.vue') },
  { path: '/register', name: 'register', component: () => import('../views/Register.vue') },
  {
    path: '/',
    component: AppLayout,
    meta: { requiresAuth: true },
    children: [
      { path: '', name: 'home', component: () => import('../views/Timetable.vue') },
      { path: 'dashboard', name: 'dashboard', component: () => import('../views/Dashboard.vue') },
      { path: 'timetable', redirect: '/' },
      { path: 'appointments', name: 'appointments', component: () => import('../views/Appointments.vue') },
      { path: 'services', name: 'services', component: () => import('../views/Services.vue') },
      { path: 'staff', name: 'staff', component: () => import('../views/Staff.vue') },
      { path: 'schedule', name: 'schedule', component: () => import('../views/Schedule.vue') },
      { path: 'clients', name: 'clients', component: () => import('../views/Clients.vue') },
      { path: 'categories', name: 'categories', component: () => import('../views/Categories.vue') },
      { path: 'loyalty', name: 'loyalty', component: () => import('../views/Loyalty.vue') },
      { path: 'loyalty/cards', name: 'loyalty-cards', component: () => import('../views/LoyaltyCards.vue') },
      { path: 'loyalty/certificates', name: 'certificates', component: () => import('../views/Certificates.vue') },
      { path: 'loyalty/subscriptions', name: 'subscriptions', component: () => import('../views/Subscriptions.vue') },
      { path: 'loyalty/deposits', name: 'deposits', component: () => import('../views/Deposits.vue') },
      { path: 'analytics', name: 'analytics', component: () => import('../views/Analytics.vue') },
      { path: 'finance', name: 'finance', component: () => import('../views/Finance.vue') },
      { path: 'payroll', name: 'payroll', component: () => import('../views/Payroll.vue') },
      { path: 'ombor', name: 'ombor', component: () => import('../views/Ombor.vue') },
      { path: 'team', name: 'team', component: () => import('../views/Team.vue') },
      { path: 'settings', name: 'booking-settings', component: () => import('../views/BookingSettings.vue') },
    ],
  },
  { path: '/:pathMatch(.*)*', redirect: '/' },
]

const router = createRouter({
  history: createWebHistory('/app/'),
  routes,
})

router.beforeEach((to) => {
  const needsAuth = to.matched.some((r) => r.meta.requiresAuth)
  if (needsAuth && !auth.isAuthed) return { path: '/login' }
  if (to.path === '/login' && auth.isAuthed) return { path: '/' }
  return true
})

export default router
