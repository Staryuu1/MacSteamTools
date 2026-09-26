# MacSteamTools

[🇮🇩 Bahasa Indonesia](README.md) | [🇬🇧 English](README_en.md)

> ⚠️ **Disclaimer**: MacSteamTools adalah **manager untuk OpenSteamTools** di macOS. Aplikasi ini **bukan** Steam itu sendiri — Steam Windows harus sudah diinstal di dalam [CrossOver](https://www.codeweavers.com/crossover). Aplikasi ini tidak berafiliasi dengan Valve, Steam, atau CodeWeavers.

---

MacSteamTools adalah launcher & manager macOS native yang memudahkan instalasi **[BetterSteamTools](https://github.com/madoiscool/BetterSteamTools)** dan pengelolaan file Lua dari **[ManifestHub](https://github.com/steamtools-games/ManifestHub3)** di CrossOver.

## ✅ Persyaratan

- macOS 13 (Ventura) atau lebih baru
- [CrossOver](https://www.codeweavers.com/crossover) terinstal
- **Steam Windows** terinstal di dalam bottle CrossOver

## 🚀 Cara Penggunaan

### 1. Setup Awal
1. Buka `MacSteamTools.app`
2. Di halaman **Settings**, pilih **bottle** CrossOver tempat Steam kamu terinstal
3. Aplikasi akan otomatis mendeteksi folder Steam — jika tidak, klik **Ubah…** untuk memilih manual
4. Pastikan Steam **sudah ditutup** sebelum melanjutkan

### 2. Pasang Modul BetterSteamTools
1. Di **Settings → Modul Steam**, klik **Pasang modul**
2. Aplikasi akan otomatis:
   - Mengunduh rilis terbaru dari GitHub
   - Mengatur 3 DLL Library di winecfg (`native,builtin`)
   - Menginstal file DLL ke folder Steam
3. Buka ulang Steam di CrossOver

### 3. Pasang Lua untuk Game
1. Buka halaman **Game**
2. Cari nama game atau App ID Steam
3. Klik **Unduh Lua** pada game yang diinginkan
4. File Lua akan otomatis disimpan ke `Steam/config/stplug-in/`
5. Buka ulang Steam untuk menerapkan perubahan

### 4. Kelola Game Terpasang
- Buka halaman **Dashboard** untuk melihat semua Lua yang sudah terpasang
- Klik ikon merah "trash" pada kartu game untuk menghapus Lua-nya
- Untuk uninstall semua sekaligus, gunakan **Settings → Danger Zone → Uninstall**

---

## 📦 Dependency Yang Di gunakan

| Komponen | Sumber |
|----------|--------|
| Modul DLL (BetterSteamTools) | [madoiscool/BetterSteamTools](https://github.com/madoiscool/BetterSteamTools) via GitHub Releases API |
| Katalog & pencarian game | [ManifestHub3](https://github.com/steamtools-games/ManifestHub3) via `steamtools.games/api/search` |
| File Lua per game | `raw.githubusercontent.com/steamtools-games/ManifestHub3/<AppID>/<AppID>.lua` |
| Cover art game | Steam CDN (`cdn.cloudflare.steamstatic.com`) |

---

## 🔧 Libraries winecfg

Sebelum DLL dipasang, aplikasi otomatis mengatur registry Wine:

| Library | Nilai |
|---------|-------|
| `dwmapi` | `native,builtin` |
| `xinput1_4` | `native,builtin` |
| `OpenSteamTool` | `native,builtin` |

Setting ini dapat dilihat di **winecfg → Libraries**. Tombol **Periksa** di Settings membaca status aktual registry.

---

## 💾 Backup & Keamanan

- Setiap instalasi DLL atau Lua membuat backup otomatis di `Steam/MacSteamTools Backups/<ID>/`
- `files.json` memetakan file tujuan ke salinan lama untuk pemulihan manual
- DLL divalidasi header MZ sebelum dipasang
- Instalasi Lua divalidasi App ID sebelum disimpan
- Tidak ada koneksi tersembunyi — semua unduhan dilakukan secara eksplisit dan ditampilkan ke pengguna

---

## 🏗️ Build

```sh
bash scripts/build.sh   # Build & kemas .app ke dist/
bash scripts/test.sh    # Jalankan test suite
```

Build menggunakan SwiftUI, AppKit, Foundation, dan CryptoKit bawaan macOS. Tidak membutuhkan Node.js, Python, atau dependency eksternal apapun.

---

## 🌐 Multi-Bahasa

Teks UI disimpan di folder `Language/`:
- `Language/id/index.json` — Bahasa Indonesia (default)
- `Language/en/index.json` — English

Untuk menambah bahasa baru: buat folder baru (misal `Language/ja/index.json`), tambahkan case di `AppLanguage` enum di `Localization.swift`, lalu build ulang.

---

## ⚠️ Catatan Penting

- Aplikasi ini hanya bekerja dengan **CrossOver** — tidak mendukung Wine biasa atau Whisky (untuk sekarang)
- Steam **harus** diinstal di dalam bottle CrossOver, bukan di macOS native
- Selalu tutup Steam sebelum menginstal modul atau Lua
- Kompatibilitas game tergantung pada ketersediaan file Lua di ManifestHub — tidak semua game tersedia
- Aplikasi ini open-source dan tidak dikaitkan secara resmi dengan proyek BetterSteamTools atau ManifestHub
