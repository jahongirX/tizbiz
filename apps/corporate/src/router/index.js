import { createRouter, createWebHistory } from 'vue-router'
import { startLoading, stopLoading } from '../composables/useNav'

// NOTE: Vite `base` is '/app/' (built assets live under /app/), but the SPA is
// served at the domain root, so the router base MUST be '/'. The server serves
// the SPA shell for any path, which is what makes deep links like /blog/<slug>
// work on refresh.
const routes = [
  { path: '/', name: 'home', component: () => import('../views/Home.vue') },
  {
    path: '/how-it-works',
    name: 'how-it-works',
    component: () => import('../views/HowItWorks.vue'),
  },
  { path: '/about', name: 'about', component: () => import('../views/About.vue') },
  { path: '/blog', name: 'blog', component: () => import('../views/BlogList.vue') },
  {
    path: '/blog/:slug',
    name: 'blog-post',
    component: () => import('../views/BlogPost.vue'),
  },
  { path: '/:pathMatch(.*)*', name: 'not-found', component: () => import('../views/NotFound.vue') },
]

const router = createRouter({
  history: createWebHistory('/'),
  routes,
  scrollBehavior(to, from, savedPosition) {
    // Anchor links (e.g. /#pricing): wait a beat so the target page has mounted,
    // then smooth-scroll to the element with an offset for the sticky nav.
    if (to.hash) {
      return new Promise((resolve) => {
        setTimeout(() => resolve({ el: to.hash, top: 76, behavior: 'smooth' }), 320)
      })
    }
    if (savedPosition) return savedPosition
    return { top: 0 }
  },
})

router.beforeEach(() => {
  startLoading()
  return true
})

router.afterEach(() => {
  stopLoading()
})

router.onError(() => {
  stopLoading()
})

export default router
