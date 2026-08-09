<script setup>
import { RouterLink } from 'vue-router'
import { posts, formatDate } from '../data/posts'
</script>

<template>
  <main>
    <section class="container page-header">
      <span class="eyebrow">Blog</span>
      <h1>Booking, loyallik va biznes o‘sishi haqida</h1>
      <p>No-show, oldindan to‘lov, Telegram bot va mijozni qaytarish bo‘yicha amaliy maqolalar.</p>
    </section>

    <section class="section" style="padding-top: 20px">
      <div class="container">
        <div class="grid posts">
          <router-link
            v-for="post in posts"
            :key="post.slug"
            class="card post-card"
            :to="`/blog/${post.slug}`"
          >
            <div class="post-card__cover" :style="{ background: post.cover }">
              <span class="tag post-card__tag">{{ post.category }}</span>
            </div>
            <div class="post-card__body">
              <h2>{{ post.title }}</h2>
              <p>{{ post.excerpt }}</p>
              <time class="post-card__date" :datetime="post.date">{{ formatDate(post.date) }}</time>
            </div>
          </router-link>
        </div>
      </div>
    </section>
  </main>
</template>

<style scoped>
.posts {
  grid-template-columns: repeat(3, 1fr);
}
.post-card {
  padding: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  transition: transform 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease;
}
.post-card:hover {
  transform: translateY(-3px);
  border-color: var(--accent);
  box-shadow: var(--shadow);
}
.post-card__cover {
  position: relative;
  height: 150px;
}
.post-card__tag {
  position: absolute;
  left: 16px;
  bottom: 16px;
  background: rgba(255, 255, 255, 0.9);
  color: #10151c;
}
.post-card__body {
  padding: 22px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex: 1;
}
.post-card__body h2 {
  font-size: 18px;
  margin: 0;
  letter-spacing: -0.01em;
  line-height: 1.3;
}
.post-card__body p {
  margin: 0;
  color: var(--text-soft);
  font-size: 14.5px;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.post-card__date {
  margin-top: auto;
  color: var(--text-soft);
  font-size: 13px;
  font-weight: 500;
}

@media (max-width: 900px) {
  .posts {
    grid-template-columns: repeat(2, 1fr);
  }
}
@media (max-width: 560px) {
  .posts {
    grid-template-columns: 1fr;
  }
}
</style>
