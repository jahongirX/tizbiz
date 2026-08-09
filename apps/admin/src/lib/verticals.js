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

export { BY_KEY as VERTICAL_BY_KEY }
