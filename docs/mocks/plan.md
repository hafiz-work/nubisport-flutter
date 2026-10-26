# Pelan Mock Data

Dokumen ini menerangkan kenapa mock data wujud, di mana ia digunakan, dan cara
menambah/menggantikannya apabila backend sebenar tersedia.

## Tujuan

- Membolehkan UI dibina dan diuji tanpa API sebenar.
- Memberi data yang konsisten antara feature (contoh: aktiviti milik akaun demo
  yang sama digunakan untuk login).
- Memudahkan peralihan ke API sebenar: UI hanya bergantung pada interface
  domain + provider, bukan implementasi mock.

## Prinsip

1. **Satu sumber akaun demo** — `lib/core/mock/mock_accounts.dart`.
   Semua feature merujuk id/name/email yang sama.
2. **Interface dahulu** — mock mengimplementasikan interface domain
   (`AuthRepository`, `ActivityRepository`), bukan bercakap terus dengan UI.
3. **Provider sebagai suis** — UI membaca provider; tukar implementasi di
   provider, UI tidak berubah.
4. **Deterministik** — id, tarikh dan koordinat tetap supaya screenshot/test
   konsisten.
5. **Tiada rahsia** — mock tidak menyimpan API key/token sebenar.
6. **Latency boleh inject** — default 450–500ms untuk rasa "network"; test guna
   `Duration.zero`.

## Status semasa

| Feature                          | Interface            | Mock                         | Real API                           | Suis                               |
| -------------------------------- | -------------------- | ---------------------------- | ---------------------------------- | ---------------------------------- |
| Auth (login/register/forgot)     | `AuthRepository`     | `MockAuthRepository`         | `AuthRepositoryImpl` (Dio + Drift) | `IS_MOCK` env → `AppConfig.isMock` |
| Activities (senarai/feed/detail) | `ActivityRepository` | `MockActivityRepository`     | belum ada                          | sentiasa mock buat masa ini        |
| Kudos                            | —                    | state lokal dalam `FeedPage` | belum ada                          | —                                  |

## Cara guna (auth mock)

1. `IS_MOCK=true` dalam `.env.dev` (`false` dalam `.env.prod`/`.env.example`).
2. Envied membaca nilai semasa build, jadi selepas tukar:
   ```bash
   dart run build_runner build
   ```
3. Jalankan app, log masuk dengan salah satu akaun demo di
   [structure.md](structure.md#akaun-demo).
4. `AuthController` memilih `MockAuthRepository` melalui `authRepositoryProvider`
   apabila `AppConfig.isMock == true`.

## Cara tambah mock untuk feature baru

1. Buat interface dalam `features/<feature>/domain/`.
2. Buat implementasi mock dalam `features/<feature>/data/mock_<feature>_repository.dart`.
3. Tambah provider dalam `features/<feature>/data/` yang memilih mock/real.
4. Jika perlu akaun, guna `MockAccounts` — jangan cipta id/nama baru.
5. Tambah seed data dengan tarikh/koordinat tetap.
6. Tambah test untuk mock (latency `Duration.zero`).
7. Kemas kini `docs/mocks/structure.md` dan jadual status di atas.

## Fasa

### Fasa 1 — Auth (siap)
- Login, register, forgot password.
- Akaun demo + kes khas (`banned@nubi.test`, `unverified@nubi.test`).

### Fasa 2 — Aktiviti (siap, mock)
- Senarai aktiviti sendiri (ikut `userId` yang login).
- Feed komuniti.
- Detail dinamik dengan statistik, nota, split dan map.
- Kudos masih lokal (belum disimpan).

### Fasa 3 — Pelan latihan (seterusnya)
- Mock `TrainingPlanRepository`: pelan 5K/10K/21K/42K, minggu, sesi.
- Sambung ke dashboard dan aktiviti.

### Fasa 4 — Komuniti & akaun
- Profil awam, follow, komen, kudos persistence.
- Mock `CommunityRepository` menggunakan `MockAccounts`.

### Fasa 5 — Migrasi API
- Implementasi real untuk setiap interface.
- Provider pilih real bila `IS_MOCK=false` (atau mengikut platform).
- Mock dikekalkan untuk test/screenshot.

## Peraturan data

- `userId` mesti wujud dalam `MockAccounts.all`.
- Tarikh guna `DateTime(2026, ...)` tetap, bukan `DateTime.now()`.
- Koordinat di Malaysia (selaras dengan lokasi sebenar).
- Jangan letak token/API key/password sebenar.
- Tambah `latency` dan biarkan test override ke `Duration.zero`.

## Limitasi

- Semua state hilang bila app restart (in-memory).
- Register menambah akaun dalam sesi semasa sahaja; akaun baru belum ada seed
  aktiviti, jadi "Aktiviti saya" kosong sehingga data ditambah.
- Kudos belum disimpan ke mana-mana.
- Tiada pagination, offline cache, atau error simulasi (selain latency).
- Tile map guna pelayan OSM awam; production perlu tile server sendiri/provider.

## Testing

- Test unit mock: `test/activity_test.dart`.
- Widget test guna provider override atau `Duration.zero`.
- Bila tukar mock, pastikan `flutter analyze` bersih dan test lama masih lulus.
