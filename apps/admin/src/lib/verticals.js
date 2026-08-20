// Business verticals — the single source of truth shared by the registration
// wizard (step 1 cards), the per-vertical demo logins, and the admin shell
// theming. Each maps to a backend engine (barber->slot, cafe->catalog,
// clinic->medical, rental->rental) and carries its accent + terminology so the
// same booking core presents itself appropriately per business type.
import { Scissors, UtensilsCrossed, Stethoscope, Shirt } from 'lucide-vue-next'

export const VERTICALS = [
  {
    key: 'barber',
    engine: 'slot',
    category: 'barber',
    title: 'Barber / Go‘zallik saloni',
    short: 'Barber',
    hint: 'Sartaroshxona, go‘zallik, styling',
    icon: Scissors,
    accent: '#3b82f6',
    terms: { services: 'Xizmatlar', staff: 'Ustalar', appointments: 'Navbatlar' },
    demoPhone: '+998901111111',
    // One engine, two business types — the owner picks which one they are so the
    // shell doesn't label a beauty salon "Barber".
    // `label` is for the picker, `short` for the sidebar badge.
    subCategories: [
      {
        value: 'barber',
        label: 'Sartaroshxona / Barber',
        short: 'Barber',
        samples: {
          bizName: 'Barber King',
          slug: 'barber-king',
          serviceCategory: 'Soch olish',
          staffRole: 'Usta / Sartarosh',
        },
      },
      {
        value: 'salon',
        label: 'Go‘zallik saloni',
        short: 'Salon',
        samples: {
          bizName: 'Aziza Beauty',
          slug: 'aziza-beauty',
          serviceCategory: 'Soch parvarishi',
          staffRole: 'Usta / Stilist',
        },
      },
    ],
    samples: {
      bizName: 'Barber King',
      slug: 'barber-king',
      tagline: 'Onlayn navbat olish',
      serviceName: 'Soch olish',
      serviceDesc: 'Xizmat haqida qisqacha ma’lumot',
      serviceCategory: 'Soch olish',
      staffRole: 'Usta / Sartarosh',
      catalogWord: 'Xizmatlar',
    },
  },
  {
    key: 'cafe',
    engine: 'catalog',
    category: 'cafe',
    title: 'Kafe / Restoran / Tortlar',
    short: 'Kafe / Tort',
    hint: 'Kafe, restoran, shirinliklar, tortlar',
    icon: UtensilsCrossed,
    accent: '#f97316',
    terms: { services: 'Menyu', staff: 'Xodimlar', appointments: 'Buyurtmalar' },
    demoPhone: '+998902222222',
  },
  {
    key: 'clinic',
    engine: 'medical',
    category: 'clinic',
    title: 'Klinika / UZI / Stomatologiya',
    short: 'Klinika',
    hint: 'Klinika, diagnostika, stomatologiya',
    icon: Stethoscope,
    accent: '#10b981',
    terms: { services: 'Xizmatlar', staff: 'Shifokorlar', appointments: 'Qabullar' },
    demoPhone: '+998903333333',
  },
  {
    key: 'rental',
    engine: 'rental',
    category: 'rental',
    title: 'Kelin ko‘ylak / Kostyum ijarasi',
    short: 'Ijara',
    hint: 'Kiyim ijarasi, kelin liboslari',
    icon: Shirt,
    accent: '#8b5cf6',
    terms: { services: 'Buyumlar', staff: 'Xodimlar', appointments: 'Ijaralar' },
    demoPhone: '+998904444444',
  },
]

const BY_KEY = Object.fromEntries(VERTICALS.map((v) => [v.key, v]))
const BY_ENGINE = Object.fromEntries(VERTICALS.map((v) => [v.engine, v]))

// Extra registration categories that still map onto a vertical's engine but are
// not their own card (kept for the detailed category, resolved to a vertical).
const CATEGORY_ALIAS = {
  salon: 'barber',
  dentistry: 'clinic',
  diagnostics: 'clinic',
  restaurant: 'cafe',
}

/** Resolve a business's vertical profile (by category, alias, then engine). */
export function verticalFor(business) {
  if (!business) return VERTICALS[0]
  const cat = business.category
  if (cat && BY_KEY[cat]) return BY_KEY[cat]
  if (cat && CATEGORY_ALIAS[cat] && BY_KEY[CATEGORY_ALIAS[cat]]) return BY_KEY[CATEGORY_ALIAS[cat]]
  if (business.engine && BY_ENGINE[business.engine]) return BY_ENGINE[business.engine]
  return VERTICALS[0]
}

/**
 * Short label for the business's own category, not just its vertical: a salon
 * runs on the barber vertical but must not be badged "Barber". Categories
 * without their own label fall back to the vertical's short name.
 */
const CATEGORY_LABEL = Object.fromEntries(
  VERTICALS.flatMap((v) => (v.subCategories || []).map((s) => [s.value, s.short || s.label])),
)

/**
 * Example texts (placeholders, hints) shown in forms. The defaults are what the
 * admin has always shown; a vertical — and, more precisely, a sub-category —
 * overrides only the lines that would read wrong for it. Verticals without their
 * own `samples` keep the defaults untouched.
 */
const SAMPLES_DEFAULT = {
  bizName: 'Shirin Tort',
  slug: 'aziza-tortlari',
  tagline: 'Onlayn buyurtma',
  serviceName: 'Soch olish',
  serviceDesc: 'Mahsulot haqida qisqacha ma’lumot',
  serviceCategory: 'Tortlar',
  staffRole: 'Usta / Shifokor / Registratura',
  catalogWord: 'Menyu/xizmatlar',
}

export function samplesFor(business) {
  const vertical = verticalFor(business)
  const sub = (vertical.subCategories || []).find((s) => s.value === business?.category)
  return { ...SAMPLES_DEFAULT, ...(vertical.samples || {}), ...(sub?.samples || {}) }
}

/**
 * Barbershop-or-salon behaviour (several services on one visit, sectioned
 * service menus). Other business types that share the same engine keep the
 * simpler flows, so this is the single place that decides.
 */
const BARBER_CATEGORIES = ['barber', 'salon']

export function isBarberShop(business) {
  return BARBER_CATEGORIES.includes(String(business?.category || ''))
}

export function categoryLabel(business) {
  const vertical = verticalFor(business)
  return CATEGORY_LABEL[business?.category] || vertical.short
}

export { BY_KEY as VERTICAL_BY_KEY }
