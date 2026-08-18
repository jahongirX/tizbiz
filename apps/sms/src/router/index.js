import { createRouter, createWebHistory } from 'vue-router'
import { auth } from '@tizbiz/api-client'

const routes = [
  { path: '/login', name: 'login', component: () => import('../views/Login.vue') },
  {
    path: '/',
    component: () => import('../components/AppLayout.vue'),
    children: [
      { path: '', name: 'stats', component: () => import('../views/Stats.vue') },
      { path: 'devices', name: 'devices', component: () => import('../views/Devices.vue') },
      { path: 'send', name: 'send', component: () => import('../views/Send.vue') },
      { path: 'messages', name: 'messages', component: () => import('../views/Messages.vue') },
      { path: 'templates', name: 'templates', component: () => import('../views/Templates.vue') },
      { path: 'contacts', name: 'contacts', component: () => import('../views/Contacts.vue') },
      { path: 'blacklist', name: 'blacklist', component: () => import('../views/Blacklist.vue') },
      { path: 'api', name: 'api', component: () => import('../views/Api.vue') },
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
