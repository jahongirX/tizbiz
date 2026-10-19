# Bizcat — brand guide

Bizcat — shahar biznes katalogi (TizBiz ekotizimining B2C tomoni). Belgi: jilmayib turgan mushuk boshi + xarita pini.

Belgi (2026-10 yangilangan): yumaloq bosh (doira) + yumshoq quloqlar + pin uchi; "kulayotgan" yumuq ko'zlar, pushti yonoqlar, kichik burun va "ω" tabassum. Do'stona, zamonaviy, tekis (flat) uslub. Favicon'da yonoq va og'iz yo'q (kichik o'lchamda o'qilishi uchun).

## Fayllar
| Fayl | Qayerda ishlatiladi |
|---|---|
| `bizcat-logo-on-dark.svg` | Indigo/qorong'i fonda header, splash |
| `bizcat-logo-on-light.svg` | Oq/krem fonda header, hujjatlar |
| `bizcat-logo-mono-indigo.svg` | Bir rangli (pechat, gravyura) |
| `bizcat-mark.svg` | Faqat belgi (xaritadagi pin, avatar, loader) |
| `bizcat-app-icon.svg` + `png/bizcat-app-icon-*.png` | PWA/Android/iOS ikonka (1024, 512, 192, 180) |
| `bizcat-favicon.svg` + `png/bizcat-favicon-*.png` | Favicon (32, 48) |

Wordmark SVG'larda konturga aylantirilgan — shrift o'rnatilmasa ham to'g'ri ko'rinadi.

## Ranglar
```css
:root {
  --bz-indigo: #1E1B4B;      /* asosiy: header, matn, tugmalar foni */
  --bz-indigo-700: #312E81;  /* hover */
  --bz-apricot: #FF8A5B;     /* aksent: CTA, pinlar, "cat" */
  --bz-apricot-600: #F26A35; /* hover */
  --bz-cream: #FAF6F0;       /* sahifa foni */
  --bz-white: #FFFFFF;       /* kartalar */
  --bz-muted: #5B5785;       /* ikkinchi darajali matn */
  --bz-border: #ECE5DA;
}
```
Qoidalar: aksent (o'rik) faqat CTA, xarita pinlari va brend elementlarida — matn rangi sifatida mayda yozuvda ishlatilmaydi (kontrast past). Oq matn o'rik fonda emas, indigo matn o'rik fonda.

## Shrift
- Sarlavha va logotip: **Sora** 600/700 (Google Fonts, lotin + kirill)
- Matn: **Manrope** 500/700
```html
<link href="https://fonts.googleapis.com/css2?family=Sora:wght@300;600;700&family=Manrope:wght@500;700&display=swap" rel="stylesheet">
```

## Ishlatish
- Logo atrofida bo'sh joy ≥ belgi kengligining 1/3 qismi.
- Minimal o'lcham: to'liq logo 120px kenglik, belgi 24px. 32px dan kichikda `bizcat-favicon.svg` (soddalashtirilgan) ishlatiladi.
- Logoni cho'zmang, rang almashtirmang, soya qo'shmang.
