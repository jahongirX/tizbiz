<script setup>
import { computed, watchEffect } from 'vue'
import { useRoute, RouterLink } from 'vue-router'
import { posts, getPost, formatDate } from '../data/posts'

const route = useRoute()

const post = computed(() => getPost(route.params.slug))

const related = computed(() => {
  if (!post.value) return []
  return posts.filter((p) => p.slug !== post.value.slug).slice(0, 2)
})

// Keep the document title in sync with the article for the browser tab.
watchEffect(() => {
  document.title = post.value
    ? `${post.value.title} — TizBiz blog`
    : 'Maqola topilmadi — TizBiz'
})
</script>

<template>
  <main>
    <!-- Missing / unknown slug -->
    <section v-if="!post" class="container missing">
      <span class="tag">404</span>
      <h1>Maqola topilmadi</h1>
      <p>Bu havola bo‘yicha maqola yo‘q — u ko‘chirilgan yoki o‘chirilgan bo‘lishi mumkin.</p>
      <router-link class="btn btn-primary" to="/blog">Blogga qaytish</router-link>
    </section>

    <template v-else>
      <article class="article">
        <div class="container article__head">
          <router-link class="back-link" to="/blog">← Blogga qaytish</router-link>
          <div class="article__meta">
            <span class="tag">{{ post.category }}</span>
            <time :datetime="post.date">{{ formatDate(post.date) }}</time>
          </div>
          <h1>{{ post.title }}</h1>
          <p class="article__excerpt">{{ post.excerpt }}</p>
        </div>

        <div class="container">
          <div class="article__cover" :style="{ background: post.cover }"></div>
        </div>

        <div class="container article__body">
          <div class="prose">
            <template v-for="(block, i) in post.body" :key="i">
              <h2 v-if="block.type === 'h2'">{{ block.text }}</h2>
              <blockquote v-else-if="block.type === 'quote'">{{ block.text }}</blockquote>
              <ul v-else-if="block.type === 'list'">
                <li v-for="(item, j) in block.items" :key="j">{{ item }}</li>
              </ul>
              <p v-else>{{ block.text }}</p>
            </template>
          </div>
        </div>
      </article>

      <!-- RELATED -->
      <section v-if="related.length" class="section section--soft">
        <div class="container">
          <div class="section-head" style="margin-bottom: 32px">
            <span class="eyebrow">Yana o‘qing</span>
            <h2>Boshqa maqolalar</h2>
          </div>
          <div class="related">
            <router-link
              v-for="rp in related"
              :key="rp.slug"
              class="card related-card"
              :to="`/blog/${rp.slug}`"
            >
              <div class="related-card__cover" :style="{ background: rp.cover }">
                <span class="tag related-card__tag">{{ rp.category }}</span>
              </div>
              <div class="related-card__body">
                <h3>{{ rp.title }}</h3>
                <time :datetime="rp.date">{{ formatDate(rp.date) }}</time>
              </div>
            </router-link>
          </div>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.missing {
  text-align: center;
  padding: 90px 20px 100px;
}
.missing h1 {
  font-size: clamp(28px, 5vw, 40px);
  margin: 16px 0 12px;
  letter-spacing: -0.02em;
}
.missing p {
  color: var(--text-soft);
  max-width: 460px;
  margin: 0 auto 24px;
}

.article__head {
  max-width: 760px;
  padding-top: 48px;
  text-align: center;
}
.article__meta {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 14px;
  margin: 22px 0 16px;
  color: var(--text-soft);
  font-size: 14px;
  font-weight: 500;
}
.article__head h1 {
  font-size: clamp(28px, 5vw, 44px);
  line-height: 1.14;
  letter-spacing: -0.02em;
  margin: 0 auto 14px;
}
.article__excerpt {
  color: var(--text-soft);
  font-size: clamp(16px, 2vw, 19px);
  margin: 0 auto;
  max-width: 620px;
}
.article__cover {
  height: clamp(180px, 34vw, 340px);
  border-radius: 20px;
  margin: 36px auto 8px;
  max-width: 900px;
  box-shadow: var(--shadow);
}
.article__body {
  max-width: 720px;
  padding-top: 36px;
  padding-bottom: 24px;
}

.related {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px;
  max-width: 900px;
  margin: 0 auto;
}
.related-card {
  padding: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  transition: transform 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease;
}
.related-card:hover {
  transform: translateY(-3px);
  border-color: var(--accent);
  box-shadow: var(--shadow);
}
.related-card__cover {
  position: relative;
  height: 120px;
}
.related-card__tag {
  position: absolute;
  left: 14px;
  bottom: 14px;
  background: rgba(255, 255, 255, 0.9);
  color: #10151c;
}
.related-card__body {
  padding: 18px 20px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.related-card__body h3 {
  font-size: 16px;
  margin: 0;
  letter-spacing: -0.01em;
  line-height: 1.3;
}
.related-card__body time {
  color: var(--text-soft);
  font-size: 13px;
  font-weight: 500;
}

@media (max-width: 560px) {
  .related {
    grid-template-columns: 1fr;
  }
}
</style>
