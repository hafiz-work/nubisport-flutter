# Struktur Mock Data

## Folder

```text
lib/
  core/
    mock/
      mock_accounts.dart          # satu sumber akaun demo (id, nama, e-mel, role)
  features/
    auth/
      data/
        data_sources/                  # remote (Dio) + local (Drift)
        repositories/
          mock_auth_repository.dart    # login/register/forgot (in-memory)
          auth_repository_impl.dart    # provider: Mock vs Dio/Drift
      domain/
        models/app_user.dart
        repositories/auth_repository.dart
      presentation/{controllers,pages,widgets}/
    activities/
      data/repositories/
        mock_activity_repository.dart  # seed aktiviti
        activity_repository_provider.dart
      domain/
        models/activity.dart
        repositories/activity_repository.dart
      presentation/
        controllers/activity_providers.dart  # FutureProvider (feed, mine, detail)
        pages/                         # activities, feed, activity_detail
        widgets/                       # card, map, share sheet, ...
    plans/      domain/models/ + presentation/pages/
    profile/    presentation/pages/
    settings/   presentation/{pages,widgets}/
docs/mocks/
  plan.md
  structure.md
```

## Tanggungjawab fail

| Fail                                                         | Tanggungjawab                                                                                 |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| `core/mock/mock_accounts.dart`                               | Definisi `MockAccount` + senarai akaun demo. Tiada import domain/Flutter.                     |
| `features/auth/data/repositories/mock_auth_repository.dart`            | Tukar `MockAccount` → `AppUser`, semak password, sesi in-memory, register akaun baru.         |
| `features/activities/data/repositories/mock_activity_repository.dart`    | Seed `Activity` (termasuk lat/lng/route). Tapis `myActivities` ikut `userId`.                 |
| `features/activities/data/repositories/activity_repository_provider.dart` | Pilih implementasi repository (buat masa ini sentiasa mock).                                  |
| `features/activities/presentation/controllers/activity_providers.dart`  | `myActivitiesProvider` baca user login; `activityFeedProvider`; `activityDetailProvider(id)`. |
| `features/activities/presentation/pages/feed_page.dart`            | Senarai feed; simpan set id yang diberi kudos (state lokal).                                  |
| `widgets/activity_map.dart`                                  | Peta OSM, marker, polyline, animasi lukis route.                                              |

## Aliran data

```text
UI (ConsumerWidget)
  └─ ref.watch(provider)
       └─ ActivityRepository (interface)
            └─ MockActivityRepository
                 ├─ MockAccounts (userId/name)
                 └─ seed List<Activity>
```

Auth:

```text
LoginPage → AuthController → AuthRepository (interface)
                                ├─ MockAuthRepository      (IS_MOCK=true)
                                └─ AuthRepositoryImpl      (IS_MOCK=false)
```

## Akaun demo

Semua password: `Password123!` (kecuali kes khas di bawah).

|   Id | Nama        | E-mel               | Role  | App role    | Boleh login |
| ---: | ----------- | ------------------- | ----- | ----------- | ----------- |
|    1 | Ahli Demo   | `ahli@nubi.test`    | user  | nubi: ahli  | ya          |
|    2 | Admin Demo  | `admin@nubi.test`   | admin | nubi: admin | ya          |
|    3 | Aina Rahman | `aina@nubi.test`    | user  | nubi: ahli  | ya          |
|    4 | Haziq Omar  | `haziq@nubi.test`   | user  | nubi: ahli  | ya          |
|    5 | Mei Ling    | `meiling@nubi.test` | user  | nubi: ahli  | ya          |
|    6 | Farid Zul   | `farid@nubi.test`   | user  | nubi: ahli  | ya          |

Kes khas login:

| E-mel                       | Keputusan                              |
| --------------------------- | -------------------------------------- |
| `banned@nubi.test`          | `AuthFailureReason.banned`             |
| `unverified@nubi.test`      | `AuthFailureReason.emailUnverified`    |
| e-mel lain / password salah | `AuthFailureReason.invalidCredentials` |

## Seed aktiviti

Tarikh tetap (Okt 2026), koordinat di Malaysia.
`Aktiviti saya` menapis `activity.userId == user.id`, jadi log masuk sebagai
`ahli@nubi.test` tunjuk aktiviti Ahli, `admin@nubi.test` tunjuk aktiviti Admin.

| Id  | User id | User        | Jenis | Tajuk                     |    Jarak | Lokasi                  |
| --- | ------: | ----------- | ----- | ------------------------- | -------: | ----------------------- |
| a1  |       1 | Ahli Demo   | run   | Larian Subuh Taman Botani |  5.02 km | Taman Botani, Shah Alam |
| a2  |       1 | Ahli Demo   | run   | Easy Run Sungai Klang     |  8.10 km | Taman Tasik Titiwangsa  |
| a3  |       1 | Ahli Demo   | run   | Long Run Bukit Cahaya     | 15.30 km | Bukit Cahaya Seri Alam  |
| a4  |       3 | Aina Rahman | run   | Interval 6x400m           |  4.82 km | Stadium Mini Seksyen 13 |
| a5  |       4 | Haziq Omar  | hike  | Trail Run Bukit Gasing    | 10.62 km | Bukit Gasing, PJ        |
| a6  |       5 | Mei Ling    | walk  | Recovery Walk             |  3.20 km | KLCC Park               |
| a7  |       6 | Farid Zul   | ride  | Ride Santai Putrajaya     | 24.50 km | Presint 2, Putrajaya    |
| a8  |       2 | Admin Demo  | run   | Shakeout Run Presint 1    |  4.20 km | Presint 1, Putrajaya    |

Setiap aktiviti ada `latitude`, `longitude`, `route` (senarai `GeoPoint`) untuk
polyline dan animasi peta.

## Kudos

- Feed menyimpan `Set<String>` id dalam `_FeedPageState`.
- Tekan butang kudos: ikon jadi hati penuh, kiraan +1 (state lokal).
- Belum disimpan ke repository/API. Bila real API siap, pindahkan ke
  `ActivityRepository` + provider.

## Dashboard

- `HomePage` (ConsumerWidget) membaca `myActivitiesProvider` — data yang sama
  dengan tab Aktiviti, ditapis mengikut akaun yang login.
- "Ringkasan 7 hari terakhir": bilangan larian, jumlah jarak, jumlah masa.
- "Aktiviti terkini": 2 aktiviti terbaru → tap buka detail; "Lihat semua" tukar
  ke tab Aktiviti (callback `onOpenActivities` dari `MainShell`).
- Pintasan Komuniti/Profil tukar tab; Mula larian/Pelan latihan masih "akan datang".
- Seed aktiviti bertarikh Okt 2026. Jika tarikh sistem jauh kemudian, ringkasan
  "7 hari terakhir" akan jadi 0 (senarai aktiviti terkini masih dipaparkan).

## Map

- `flutter_map` + `latlong2`, tile raster **OpenStreetMap** (keyless) sebagai
  fallback buat masa ini.
- Feed: preview 120px, tidak interaktif, route penuh (tiada animasi).
- Detail: 220px, interaktif, `animateRoute: true` — kamera fit route, tunggu
  400ms, kemudian line dilukis 2.4s dari start ke end dengan dot bergerak.
- Attribution `OpenStreetMap contributors` tersembunyi di sebalik ikon **"i"**;
  wajib kekal (terma OSM).
- **CARTO raster kini perlukan API key** (sejak Sep 2026) — jangan guna URL
  `basemaps.cartocdn.com/light_all` tanpa key.
- Produksi yang sepadan dengan web (MapLibre): tukar `ActivityMap` kepada
  `maplibre_gl` + style OpenFreeMap Positron/Liberty (vector, tanpa key). Perlu
  JDK 21 untuk build Android, Android API 21+, iOS 13+, Flutter 3.29+.

## Suis mock/real (auth)

| Tempat                       | Nilai                                |
| ---------------------------- | ------------------------------------ |
| `.env.dev`                   | `IS_MOCK=true`                       |
| `.env.prod` / `.env.example` | `IS_MOCK=false`                      |
| `lib/core/config/env.dart`   | `isMock` (envied)                    |
| `AppConfig`                  | `isMock`                             |
| `authRepositoryProvider`     | pilih `MockAuthRepository` bila true |

Selepas tukar env: `dart run build_runner build` (envied bake nilai semasa build).

## Menambah data

1. Tambah akaun baru dalam `MockAccounts` (jika perlu).
2. Tambah `Activity` dalam `_activities` dengan id unik, `userId` sah,
   tarikh/koordinat tetap.
3. Jika feature baru: ikut langkah dalam [plan.md](plan.md#cara-tambah-mock-untuk-feature-baru).
4. Kemas kini jadual di dokumen ini.
