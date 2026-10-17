// Raw JSON bodies copied from docs/mobile/BACKEND-PLAN.md §4 (placeholders `{...}` filled in
// with the shapes documented there) and from the live API's PHP response builders.

// ---------- auth (BP 4.1) ----------

const loginJson = r'''
{"data":{
  "token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "expires_at":1792818720,
  "user":{"id":4,"phone":"+998901111111","name":"Shoxrux Karimov","status":10,"is_superadmin":false,"created_at":1784364000,"updated_at":1792213920},
  "businesses":[{"id":2,"name":"Shox Barber","slug":"shox-barber","category":"barber","engine":"slot","logo":"https://api.tizbiz.uz/uploads/202609/a1b2.png","role":"business_owner"}],
  "active":{"business_id":2,"role":"business_owner","staff_id":null,
            "permissions":["appointments.all","appointments.manage","orders","clients","analytics","finance","payroll","loyalty","inventory","catalog.manage","team.read","team.manage","settings.manage","reviews","uploads","me"]}
}}
''';

/// Live login (before BACKEND-PLAN): is_superadmin as 0, no expires_at, no staff_id/permissions,
/// engine missing.
const loginLiveJson = r'''
{"data":{
  "token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.legacy",
  "user":{"id":31,"phone":"+998931110001","name":"Usta Jahongir","status":10,"is_superadmin":0,"created_at":1784364000,"updated_at":1792213920},
  "businesses":[{"id":2,"name":"Shox Barber","slug":"shox-barber","category":"barber","logo":null,"role":"staff"}],
  "active":{"business_id":2,"role":"staff"}
}}
''';

const authMeJson = r'''
{"data":{"user":{"id":31,"phone":"+998931110001","name":"Usta Jahongir","status":10,"is_superadmin":0,"created_at":1784364000,"updated_at":1792213920},
  "active":{"business_id":2,"role":"staff","staff_id":7,"permissions":["orders","me"]},
  "businesses":[{"id":2,"name":"Shox Barber","slug":"shox-barber","category":"barber","engine":"slot","logo":null,"role":"staff"},
                {"id":3,"name":"Aziza Tortlari","slug":"aziza-tortlari","category":"cafe","engine":"catalog","logo":null,"role":"staff"}]}}
''';

const switchJson = r'''
{"data":{"token":"eyJ.switched.token","expires_at":1792818720,"active":{"business_id":3,"role":"staff","staff_id":12,"permissions":["orders","me"]}}}
''';

// ---------- team (BP 4.2) ----------

const teamListJson = r'''
{"data":[
  {"user_id":4,"name":"Shoxrux Karimov","phone":"+998901111111","role":"business_owner","staff_id":null},
  {"user_id":31,"name":"Usta Jahongir","phone":"+998931110001","role":"staff","staff_id":2}
]}
''';

const teamPatchJson = r'''
{"data":{"user_id":31,"role":"staff","staff_id":2}}
''';

// ---------- me (BP 4.3) ----------

const meStaffJson = r'''
{"data":{"id":2,"business_id":2,"name":"Usta Jahongir","specialization":"Sartarosh","commission_percent":40,"is_active":true,
         "business":{"id":2,"name":"Shox Barber","slug":"shox-barber","engine":"slot","timezone":"Asia/Tashkent","logo":null}}}
''';

const meAppointmentsJson = r'''
{"data":[{"id":5012,"business_id":2,"client_id":881,"consumer_id":17,"staff_id":2,"service_id":11,"guests":null,
  "starts_at":"2026-10-17 05:00:00","ends_at":"2026-10-17 05:40:00","status":"confirmed","source":"app",
  "deposit_tiyin":2000000,"paid":true,"notes":null,"created_at":1792054800,"updated_at":1792054800,
  "client_name":"Aziza Karimova","client_phone":"+998900000001","service_name":"Soch olish + soqol",
  "service_duration":40,"staff_name":"Usta Jahongir","items":[]}]}
''';

const meStatsJson = r'''
{"data":{
  "range":{"from":"2026-10-01","to":"2026-10-17","timezone":"Asia/Tashkent"},
  "staff":{"id":2,"name":"Usta Jahongir","commission_percent":40},
  "appointments":{"total":64,"pending":2,"confirmed":3,"arrived":0,"completed":52,"no_show":4,"canceled":3},
  "revenue_tiyin":416000000,"earnings_tiyin":166400000,"clients_served":41,
  "series":[{"date":"2026-10-01","count":4,"completed":3,"revenue_tiyin":24000000,"earnings_tiyin":9600000}],
  "today":{"total":6,"completed":2,"next_at":"2026-10-17 09:30:00"}
}}
''';

const meScheduleJson = r'''
{"data":{
  "working_hours":[{"id":21,"weekday":1,"start_time":"09:00:00","end_time":"20:00:00"}],
  "time_off":[{"id":4,"date":"2026-10-25","start_time":null,"end_time":null,"reason":"Dam olish"}]
}}
''';

// ---------- directory (BP 4.4) ----------

const directoryCategoriesJson = r'''
{"data":[{"key":"barber","label":"Barber / Go'zallik saloni","label_ru":"Барбершоп / Салон красоты","engine":"slot","icon":"scissors","count":1},
         {"key":"cafe","label":"Kafe / Tortlar","label_ru":"Кафе / Торты","engine":"catalog","icon":"cake","count":1}]}
''';

/// The BP card plus a second card whose lat/lng arrive as decimal strings.
const directoryListJson = r'''
{"data":[{
  "id":2,"slug":"shox-barber","name":"Shox Barber","category":"barber","category_label":"Barber / Go'zallik saloni",
  "engine":"slot","tagline":"Chilonzordagi eng yaxshi soch turmaklari","logo":"https://api.tizbiz.uz/uploads/202609/a1b2.png",
  "cover":null,"brand_color":"#1E1B4B","brand_color_2":null,"address":"Chilonzor 9-kvartal, 12-uy","city":"Toshkent",
  "district":"Chilonzor","lat":41.2756,"lng":69.2034,"rating_avg":4.73,"rating_count":15,"is_featured":false,
  "online_booking_enabled":true,"price_from_tiyin":5000000,"is_favorite":true},
  {"id":3,"slug":"aziza-tortlari","name":"Aziza Tortlari","category":"cafe","category_label":"Kafe / Tortlar",
  "engine":"catalog","tagline":"","logo":"","cover":null,"brand_color":"#F26A35","brand_color_2":null,"address":"Yunusobod 4-kvartal","city":"Toshkent",
  "district":"Yunusobod","lat":"41.2756000","lng":"69.2034000","rating_avg":"4.50","rating_count":"2","is_featured":1,
  "online_booking_enabled":1,"price_from_tiyin":null,"is_favorite":false}],
 "meta":{"page":1,"per_page":20,"total":5,"pages":1}}
''';

const directoryDetailJson = r'''
{"data":{
  "business":{"id":2,"slug":"shox-barber","name":"Shox Barber","category":"barber","category_label":"Barber / Go'zallik saloni",
               "engine":"slot","tagline":"Chilonzordagi eng yaxshi soch turmaklari","logo":"https://api.tizbiz.uz/uploads/202609/a1b2.png",
               "cover":null,"brand_color":"#1E1B4B","brand_color_2":null,"address":"Chilonzor 9-kvartal, 12-uy","city":"Toshkent",
               "district":"Chilonzor","lat":41.2756,"lng":69.2034,"rating_avg":4.73,"rating_count":15,"is_featured":false,
               "online_booking_enabled":true,"price_from_tiyin":5000000,"is_favorite":false,
               "phone":"+998901111111","map_url":"https://yandex.uz/maps/-/CDabc",
               "description":"Erkaklar uchun zamonaviy barbershop. 5 nafar tajribali usta.","timezone":"Asia/Tashkent",
               "telegram_bot_username":"shoxbarber_bot",
               "hours":[{"weekday":1,"open":"09:00","close":"21:00"},{"weekday":7,"open":"10:00","close":"18:00"}] },
  "rating":{"avg":4.73,"count":15,"distribution":{"1":0,"2":0,"3":1,"4":2,"5":12}},
  "reviews_preview":[{"id":88,"rating":5,"comment":"Usta juda e'tiborli, soch ajoyib chiqdi!","author_name":"Aziza K.",
                      "service_name":"Soch olish","staff_name":"Usta Jahongir","reply":"Rahmat, yana kutamiz!",
                      "replied_at":1791636000,"created_at":1791500000}],
  "is_favorite":false
}}
''';

const directoryReviewsJson = r'''
{"data":[{"id":88,"rating":5,"comment":"Usta juda e'tiborli, soch ajoyib chiqdi!","author_name":"Aziza K.",
          "service_name":"Soch olish","staff_name":"Usta Jahongir","reply":"Rahmat, yana kutamiz!",
          "replied_at":1791636000,"created_at":1791500000}],
 "meta":{"page":1,"per_page":20,"total":15,"pages":1,"avg":4.73,"count":15,"distribution":{"1":0,"2":0,"3":1,"4":2,"5":12}}}
''';

// ---------- storefront (live SlotEngine / CatalogEngine + BP 4.5) ----------

const siteSlotJson = r'''
{"data":{"engine":"slot",
  "business":{"id":2,"name":"Shox Barber","slug":"shox-barber","category":"barber","phone":"+998901111111","address":"Chilonzor 9-kvartal, 12-uy",
              "map_url":null,"timezone":"Asia/Tashkent","online_booking_enabled":true,"tagline":"Chilonzordagi eng yaxshi soch turmaklari",
              "logo":null,"cover":null,"brand_color":"#1E1B4B","brand_color_2":null},
  "services":[{"id":11,"business_id":2,"category_id":null,"name":"Soch olish + soqol","duration_min":40,"price_tiyin":8000000,"deposit_tiyin":2000000,
               "is_active":1,"online_bookable":1,"image":null,"description":null,"gallery":null,"created_at":1784364000,"updated_at":1784364000}],
  "staff":[{"id":2,"name":"Usta Jahongir","specialization":"Sartarosh"}]}}
''';

const siteCatalogJson = r'''
{"data":{"engine":"catalog",
  "business":{"id":3,"name":"Aziza Tortlari","slug":"aziza-tortlari","category":"cafe","phone":"+998902222222","address":"Yunusobod 4-kvartal",
              "map_url":null,"timezone":"Asia/Tashkent","online_booking_enabled":1,"tagline":null,"logo":null,"cover":null,"brand_color":"#F26A35","brand_color_2":null},
  "categories":[{"id":0,"name":"Boshqa","image":null,"items":[
      {"id":61,"business_id":3,"category_id":null,"name":"Napoleon torti (1 kg)","duration_min":30,"price_tiyin":22500000,"deposit_tiyin":null,
       "is_active":1,"online_bookable":0,"image":"https://api.tizbiz.uz/uploads/202609/n1.jpg","description":"Uy usulida","gallery":"[\"https://api.tizbiz.uz/uploads/202609/n2.jpg\"]","created_at":1784364000,"updated_at":1784364000}]}],
  "items":[{"id":61,"business_id":3,"category_id":null,"name":"Napoleon torti (1 kg)","duration_min":30,"price_tiyin":22500000,"deposit_tiyin":null,
       "is_active":1,"online_bookable":0,"image":"https://api.tizbiz.uz/uploads/202609/n1.jpg","description":"Uy usulida","gallery":"[\"https://api.tizbiz.uz/uploads/202609/n2.jpg\"]","created_at":1784364000,"updated_at":1784364000}]}}
''';

/// Legacy site payload: no engine key, no branding.
const siteLegacyJson = r'''
{"data":{"business":{"id":2,"name":"Shox Barber","slug":"shox-barber","category":"barber","phone":"+998901111111","timezone":"Asia/Tashkent"},
  "services":[],"staff":[]}}
''';

const availabilityJson = r'''
{"data":{"date":"2026-10-19","timezone":"Asia/Tashkent","slots":[
  {"start_utc":"2026-10-19 04:00:00","end_utc":"2026-10-19 04:40:00","start_local":"09:00"},
  {"start_utc":"2026-10-19 09:00:00","end_utc":"2026-10-19 09:40:00","start_local":"14:00"},
  {"start_utc":"2026-10-19 13:00:00","end_utc":"2026-10-19 13:40:00","start_local":"18:00"}]}}
''';

const bookedDaysJson = r'''
{"data":{"booked":{"2026-11-14":["morning","evening"],"2026-11-15":["evening"]}}}
''';

const bookedDaysEmptyJson = r'''
{"data":{"booked":[]}}
''';

// ---------- business tenant data (live) ----------

const staffListLiveJson = r'''
{"data":[{"id":2,"business_id":2,"user_id":31,"name":"Usta Jahongir","specialization":"Sartarosh","is_active":1,
          "created_at":1784364000,"updated_at":1792213920,"commission_percent":40}]}
''';

const servicesLiveJson = r'''
{"data":[{"id":11,"business_id":2,"category_id":5,"name":"Soch olish + soqol","duration_min":40,"price_tiyin":8000000,"deposit_tiyin":1000000,
          "is_active":1,"online_bookable":1,"image":null,"description":null,"gallery":null,"created_at":1784364000,"updated_at":1784364000}]}
''';

const serviceCategoriesLiveJson = r'''
{"data":[{"id":5,"business_id":2,"name":"Soch","sort":1,"image":null}]}
''';

const workingHoursLiveJson = r'''
{"data":[{"id":21,"staff_id":2,"weekday":1,"start_time":"09:00:00","end_time":"20:00:00"},
         {"id":22,"staff_id":2,"weekday":7,"start_time":"10:00:00","end_time":"18:00:00"}]}
''';

const timeOffLiveJson = r'''
{"data":[{"id":4,"staff_id":2,"date":"2026-10-25","start_time":"13:00:00","end_time":"14:00:00","reason":"Tushlik"}]}
''';

const analyticsJson = r'''
{"data":{"revenue_tiyin":48000000,
  "appointments":{"total":8,"completed":6,"no_show":0,"canceled":1,"pending":0,"confirmed":1,"arrived":0},
  "no_show_rate":0,
  "clients":{"total":120,"new":4},
  "series":[{"date":"2026-10-15","revenue_tiyin":0,"appointments":0},
            {"date":"2026-10-16","revenue_tiyin":24000000,"appointments":4},
            {"date":"2026-10-17","revenue_tiyin":24000000,"appointments":4}],
  "top_services":[{"service_id":11,"name":"Soch olish + soqol","count":6,"revenue_tiyin":48000000}],
  "staff_load":[{"staff_id":2,"name":"Usta Jahongir","count":8,"revenue_tiyin":48000000}]}}
''';

const payrollJson = r'''
{"data":{"staff":[{"staff_id":2,"name":"Usta Jahongir","commission_percent":40,"appointments":6,"revenue_tiyin":48000000,"earnings_tiyin":19200000}],
  "totals":{"revenue_tiyin":48000000,"earnings_tiyin":19200000}}}
''';

const financeSummaryJson = r'''
{"data":{"from":"2026-09-18","to":"2026-10-17","income_tiyin":6000000,"refunds_tiyin":0,"net_tiyin":6000000,"count":3,
  "by_provider":[{"provider":"payme","amount_tiyin":6000000,"count":3}]}}
''';

const financeTransactionsJson = r'''
{"data":[{"id":"301","provider":"payme","type":"deposit","status":"paid","amount_tiyin":"2000000","created_at":"1792213920",
          "appointment_id":"5012","client_name":"Aziza Karimova","service_name":"Soch olish + soqol"}],
 "meta":{"page":1,"per_page":20,"total":1,"pages":1}}
''';

/// Live settings (before BACKEND-PLAN §4.8: none of the NEW keys).
const settingsLiveJson = r'''
{"data":{"name":"Shox Barber","phone":"+998901111111","tagline":"Chilonzordagi eng yaxshi soch turmaklari","slug":"shox-barber",
  "online_booking_enabled":true,"booking_lead_min":60,"booking_horizon_days":30,"logo":null,"cover":null,
  "brand_color":"#1E1B4B","brand_color_2":null,"telegram_connected":false,"telegram_bot_username":null}}
''';

const settingsNewJson = r'''
{"data":{"name":"Shox Barber","phone":"+998901111111","tagline":"Chilonzordagi eng yaxshi soch turmaklari","slug":"shox-barber",
  "online_booking_enabled":true,"booking_lead_min":60,"booking_horizon_days":30,"logo":null,"cover":null,
  "brand_color":"#1E1B4B","brand_color_2":null,"telegram_connected":true,"telegram_bot_username":"shoxbarber_bot",
  "address":"Chilonzor 9-kvartal, 12-uy","map_url":"https://yandex.uz/maps/-/CDabc","city":"Toshkent","district":"Chilonzor","lat":41.2756,"lng":69.2034,
  "description":"Erkaklar uchun zamonaviy barbershop.","is_listed":true,"rating_avg":4.73,"rating_count":15}}
''';

/// Business order (Order::fields(), no consumer extras).
const businessOrderJson = r'''
{"data":{"id":690,"status":"delivered","total_tiyin":22500000,"customer_name":"Aziza Karimova","customer_phone":"+998900000001",
  "note":null,"source":"site","created_at":1792054800,
  "items":[{"id":1490,"service_id":61,"name":"Napoleon torti (1 kg)","price_tiyin":22500000,"qty":1}],"items_count":1}}
''';

const clientsListJson = r'''
{"data":[{"id":881,"name":"Aziza Karimova","phone":"+998900000001","email":null,"birthday":"1996-04-12","tags":"[\"vip\"]",
          "created_at":1784364000,"visits":5,"spent_tiyin":40000000,"last_visit":"2026-10-01 06:00:00",
          "categories":[{"id":1,"name":"VIP","color":"#F59E0B"}]}],
 "meta":{"page":1,"per_page":20,"total":1,"pages":1}}
''';

const clientDetailJson = r'''
{"data":{"client":{"id":881,"business_id":2,"name":"Aziza Karimova","phone":"+998900000001","email":null,"birthday":"1996-04-12",
                   "notes":"Soqolni qisqa yoqtiradi","tags":["vip"],"created_at":1784364000,"updated_at":1792213920},
  "categories":[{"id":1,"name":"VIP","color":"#F59E0B"}],
  "history":[{"id":4990,"business_id":2,"client_id":881,"consumer_id":17,"staff_id":2,"service_id":11,"guests":null,
    "starts_at":"2026-10-01 06:00:00","ends_at":"2026-10-01 06:40:00","status":"completed","source":"link",
    "deposit_tiyin":null,"paid":0,"notes":null,"created_at":1791500000,"updated_at":1791500000,
    "client_name":"Aziza Karimova","client_phone":"+998900000001","service_name":"Soch olish + soqol",
    "service_duration":40,"staff_name":"Usta Jahongir"}]}}
''';

const clientCategoriesJson = r'''
{"data":[{"id":1,"business_id":2,"name":"VIP","color":"#F59E0B","sort":1}]}
''';

// ---------- consumer (BP 4.6) ----------

const otpJson = r'''
{"data":{"sent":true,"ttl_sec":120,"retry_after_sec":60}}
''';

const verifyJson = r'''
{"data":{"token":"eyJ...","expires_at":1794805920,"is_new":false,
  "consumer":{"id":17,"phone":"+998900000001","name":"Aziza Karimova","birthday":null,"gender":"female","city":"Toshkent","locale":"uz","created_at":1792195200}}}
''';

const consumerMeJson = r'''
{"data":{"id":17,"phone":"+998900000001","name":"Aziza Karimova","birthday":"1996-04-12","gender":"female","city":"Toshkent","locale":"uz","created_at":1792195200,
         "stats":{"appointments_upcoming":1,"appointments_total":6,"orders_total":2,"reviews_total":3,"favorites_total":2}}}
''';

const consumerAppointmentsJson = r'''
{"data":[{
  "id":5012,"status":"confirmed","starts_at":"2026-10-18 05:00:00","ends_at":"2026-10-18 05:40:00","guests":null,
  "deposit_tiyin":2000000,"paid":true,"notes":null,"source":"app","created_at":1792054800,
  "business":{"id":2,"slug":"shox-barber","name":"Shox Barber","logo":null,"brand_color":"#1E1B4B","phone":"+998901111111",
              "address":"Chilonzor 9-kvartal, 12-uy","map_url":null,"timezone":"Asia/Tashkent","engine":"slot"},
  "staff":{"id":2,"name":"Usta Jahongir"},
  "service":{"id":11,"name":"Soch olish + soqol","duration_min":40,"price_tiyin":8000000},
  "can_cancel":false,"can_review":false,"review_id":null}],
 "meta":{"page":1,"per_page":20,"total":1,"pages":1}}
''';

/// Unpaid deposit booking, no `items` key.
const appointmentUnpaidJson = r'''
{"data":{"id":5013,"business_id":2,"client_id":881,"staff_id":2,"service_id":11,
  "starts_at":"2026-10-19 04:00:00","ends_at":"2026-10-19 04:40:00","status":"pending","source":"link",
  "deposit_tiyin":2000000,"paid":0,"notes":"","created_at":1792213920,"updated_at":1792213920,
  "client_name":"Aziza Karimova","client_phone":"+998900000001","service_name":"Soch olish + soqol","service_duration":40,"staff_name":"Usta Jahongir"}}
''';

const consumerOrdersJson = r'''
{"data":[{"id":702,"status":"new","total_tiyin":45000000,"customer_name":"Aziza Karimova","customer_phone":"+998900000001",
  "note":"Tug'ilgan kun uchun yozuv: Lola 7 yosh","source":"app","created_at":1792213920,
  "items":[{"id":1501,"service_id":61,"name":"Napoleon torti (1 kg)","price_tiyin":22500000,"qty":2}],"items_count":1,
  "business":{"id":3,"slug":"aziza-tortlari","name":"Aziza Tortlari","logo":null,"brand_color":"#F26A35","phone":"+998902222222",
              "address":"Yunusobod 4-kvartal","map_url":null,"timezone":"Asia/Tashkent","engine":"catalog"},
  "can_cancel":true,"can_review":false,"review_id":null}],
 "meta":{"page":1,"per_page":20,"total":1,"pages":1}}
''';

const loyaltyJson = r'''
{"data":[{"business":{"id":2,"slug":"shox-barber","name":"Shox Barber","logo":null,"brand_color":"#1E1B4B"},
          "client_id":881,"points":120,"cashback_tiyin":1500000,"deposit_balance_tiyin":0,"visits":5}]}
''';

const consumerReviewsJson = r'''
{"data":[{"id":88,"rating":5,"comment":"Usta juda e'tiborli, soch ajoyib chiqdi!","author_name":"Aziza K.",
          "service_name":"Soch olish","staff_name":"Usta Jahongir","reply":null,"replied_at":null,"created_at":1791500000,
          "business":{"id":2,"slug":"shox-barber","name":"Shox Barber","logo":null},
          "appointment_id":4990,"order_id":null,"status":"published"}]}
''';

// ---------- business reviews (BP 4.7) ----------

const businessReviewsJson = r'''
{"data":[{"id":88,"rating":5,"comment":"Usta juda e'tiborli!","author_name":"Aziza K.","status":"published",
          "appointment_id":4990,"order_id":null,"staff_id":2,"staff_name":"Usta Jahongir","service_id":11,"service_name":"Soch olish",
          "reply":null,"replied_at":null,"created_at":1791500000}],
 "meta":{"page":1,"per_page":20,"total":15,"pages":1,"avg":4.73,"count":15,"distribution":{"1":0,"2":0,"3":1,"4":2,"5":12}}}
''';

// ---------- payments (BP 4.5) ----------

const depositJson = r'''
{"data":{"transaction":{"id":301,"provider":"payme","amount_tiyin":2000000,"type":"deposit","status":"created","appointment_id":5012,"created_at":1792213920,"updated_at":1792213920},
  "provider":"payme","checkout_url":"https://checkout.paycom.uz/bT0..."}}
''';

// ---------- errors ----------

const error401Json = r'''
{"errors":[{"status":"401","title":"Unauthorized","detail":"Your request was made with invalid credentials."}]}
''';

const loginFailedJson = r'''
{"errors":[{"status":"401","title":"Unauthorized","detail":"Telefon yoki parol noto'g'ri."}]}
''';

const error422PointersJson = r'''
{"errors":[{"status":"422","title":"Validation error","detail":"Telefon raqam noto'g'ri.","source":{"pointer":"phone"}},
           {"status":"422","title":"Validation error","detail":"Tugash vaqti noto'g'ri.","source":{"pointer":"items[2].end_time"}}]}
''';

const error422GenericJson = r'''
{"errors":[{"status":"422","title":"Validation error","detail":"Bu bron uchun oldindan to'lov talab qilinmaydi."}]}
''';

const error409Json = r'''
{"errors":[{"status":"409","title":"Conflict","detail":"Tanlangan vaqt band."}]}
''';

const error403NoBusinessJson = r'''
{"errors":[{"status":"403","title":"Forbidden","detail":"No active business selected."}]}
''';

const error403RoleJson = r'''
{"errors":[{"status":"403","title":"Forbidden","detail":"Insufficient role for this action."}]}
''';

const error429Json = r'''
{"errors":[{"status":"429","title":"Too Many Requests","detail":"Kodni qayta yuborish uchun 42 soniya kuting."}]}
''';

const error409EmptyJson = r'''
{"errors":[{"status":"409","title":"Error","detail":""}]}
''';
