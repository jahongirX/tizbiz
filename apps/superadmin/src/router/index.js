import { createRouter, createWebHistory } from 'vue-router'
import { auth } from '@tizbiz/api-client'

const routes = [
  { path: '/login', name: 'login', component: () => import('../views/Login.vue') },
  {
    path: '/',
    component: () => import('../components/AppLayout.vue'),
    children: [
      { path: '', name: 'dashboard', component: () => import('../views/Dashboard.vue') },
      { path: 'leads', name: 'leads', component: () => import('../views/Leads.vue') },
      { path: 'accounts', name: 'accounts', component: () => import('../views/Accounts.vue') },
      { path: 'sales', name: 'sales', component: () => import('../views/Sales.vue') },
      { path: 'recipients', name: 'recipients', component: () => import('../views/Recipients.vue') },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

router.beforeEach((to) => {
  if (to.name !== 'login' && !auth.isAuthed) return { name: 'login' }
  if (to.name === 'login' && auth.isAuthed) return { path: '/' }
  return true
})

export default router
