Aeonik Pro — bu yerga font fayllarini tashlang
=================================================

Sayt Aeonik Pro shriftida ishlaydi. Litsenziyali fayllarni MEN yuklab bera
olmayman, shuning uchun ularni siz shu papkaga qo'yasiz. Fayl NOMLARI aynan
quyidagicha bo'lishi kerak (kichik/katta harflar ham muhim):

    apps/corporate/public/fonts/AeonikPro-Regular.woff2   (400)
    apps/corporate/public/fonts/AeonikPro-Medium.woff2    (500)
    apps/corporate/public/fonts/AeonikPro-Bold.woff2      (700)

Ixtiyoriy (bo'lsa yaxshi): .woff ham qo'ysangiz eski brauzerlar uchun:
    AeonikPro-Regular.woff / AeonikPro-Medium.woff / AeonikPro-Bold.woff

Agar sizdagi fayllar boshqa nomda bo'lsa (masalan "Aeonik-Regular.otf"),
menga ayting — @font-face'dagi nomlarni moslayman, yoki .otf/.ttf'ni .woff2'ga
o'giramiz (kichikroq va tezroq).

Fayllarni qo'ygach menga "font tayyor" deб yozing — qayta build qilib,
prodga yuboraman. Fayllar kelguncha sayt tizim shriftida (system-ui) ko'rinadi.
