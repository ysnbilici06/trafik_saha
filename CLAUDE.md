# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Trafik Saha: a Flutter app (Android, iOS, web) for Turkish traffic enforcement personnel. It bundles the fine schedules and full text of laws 2918 (Karayolları Trafik Kanunu) and 4925 (Karayolu Taşıma Kanunu), plus calculators, checklists, a quiz, accident examples, an offline Q&A assistant, a traffic news feed, weather-based road warnings and personal enforcement/accident logs. A Python scraper in `tarayici/` regenerates the data from official sources.

All identifiers, comments, UI strings and data keys are Turkish. Keep new code consistent with that.

## Commands

The project lives under a user folder containing `İ` and a space (`C:\Users\YASİN EMİNE\...`). That path crashes the Dart analysis server and breaks Android builds, so **run every Flutter/Dart command from the ASCII junction `C:\src\trafik_saha`**, which points at this directory. Flutter and Git are not on the default PATH.

```powershell
$env:Path = "C:\src\flutter\bin;C:\Program Files\Git\cmd;" + $env:Path
$env:PUB_CACHE = "C:\src\pub_cache"          # default cache is under the non-ASCII user folder; native-asset hooks fail there
Set-Location C:\src\trafik_saha

flutter analyze
flutter test
flutter test --plain-name "hız sorusu"      # single test by name
flutter run -d chrome
flutter build web
flutter build apk                            # needs JDK + Android SDK, not installed yet
```

Scraper (Python 3.12 is at `$env:LOCALAPPDATA\Programs\Python\Python312\python.exe`; set `$env:PYTHONIOENCODING = "utf-8"` or printing Turkish text fails):

```powershell
python tarayici\guncelle.py assets\veri                 # download sources, rebuild data, write announcements + manifest
python tarayici\guncelle.py assets\veri --haber         # same, and re-collect news now instead of waiting for 06:00
python tarayici\veri_olustur.py <pdf_dir> <out_dir>      # parse already-downloaded PDFs only
python tarayici\haberler.py 40                           # dry-run the news filters: prints matches, writes nothing
```

Scraper dependencies are in `tarayici\requirements.txt`. The scraper has no automated tests; `flutter test` on the regenerated data is the check.

`guncelle.py` must be re-run after hand-editing any file in `assets/veri/`, because `surum.json` stores a SHA-256 per data file.

## Architecture

### Data pipeline (`tarayici/` → `assets/veri/`)

Fine amounts, penalty points and suspension periods are never hand-written; they are parsed from official PDFs:

- `rehber_ayristir.py` parses the EGM "Trafik İdari Para Ceza Rehberi" PDF, a single 13-column table. Narrow columns are printed as 90°-rotated text, so cells are read from character coordinates and text-matrix direction, and each cell is mapped to a column by its x position (cell counts vary per page). The header appears on every page in some editions and only on page 1 in others; it is detected by content.
- `veri_olustur.py` turns PDFs into `cezalar_2918.json`, `cezalar_4925.json`, `mevzuat_2918.json`, `mevzuat_4925.json`. Law text drops footnotes by font size and splits on `Madde N –` headings.
- `guncelle.py` discovers the current guide URL on trafik.gov.tr (falling back to patterns in `kaynaklar.json`), rebuilds the data, diffs it against the existing files into `duyurular.json`, scans the Resmî Gazete index for relevant headlines, and writes `surum.json`. A source that fails to download or shrinks below 60% of its previous size is skipped so bad data is not published.
- `kitaplik.py` builds the legislation library: the other laws, regulations and communiqués listed under `kitaplik` in `kaynaklar.json` (mevzuat.gov.tr number, type, Resmî Gazete reference). Text comes from mevzuat.gov.tr's HTML text endpoint, not PDFs (several have none), and is split on `MADDE n –` headings into `mevzuat_<kod>.json` plus the index `kitaplik.json` (which also lists 2918 and 4925 first). `guncelle.py` refreshes it at most once every 24 h (`kitaplikZamani` in `surum.json`), or immediately with `--kitaplik`. To add a text, find its number with the site's title search and add an entry; internal directives (yönerge) are not published there and are deliberately absent.
- `haberler.py` builds `haberler.json` (the bell screen's news feed): Google News RSS searches plus publisher feeds, keyword-filtered into `kaza` / `mevzuat`, Turkey only. Only headline, source, date, snippet, image URL and link are stored; never article bodies. The filter regexes are heuristic, so check `python tarayici/haberler.py 200` output after changing them. `lib/veri/haberler.dart` repeats a lighter version of the search in-app on non-web platforms (browsers block these feeds via CORS), merged with the file.
- News is deliberately small and daily: at most 5 items per category (`KATEGORI_SINIRI` / `haberSiniri`), aged out after 2 days (accidents) or 14 (legislation), and refreshed once a day at 06:00 Turkey time. The workflow still runs hourly for legal data; `guncelle.py` skips the news step unless the last collection (`haberZamani` in `surum.json`) predates the latest 06:00, or `--haber` is passed. The app mirrors this with `Depo.sabahYenilemesi` (called at startup and every minute from the home clock).
- `.github/workflows/veri-guncelle.yml` runs this hourly and commits only when data (not just the check timestamp) changed.

`icerik.json` is the only hand-authored data file: quiz questions, accident scenarios, court decisions, checklists. Its `ihlaller`, `ceza` and `ceza4925` fields reference fine-item ids/article numbers in the generated files; `flutter test` fails on dangling references. Court decisions must only be added with a citation verified at the source.

### App (`lib/`)

- `veri/depo.dart` — `Depo.i`, a singleton `ChangeNotifier` holding all loaded data and all per-user state (profile, favourites, notes, checklist ticks, quiz progress) as one JSON blob in SharedPreferences. Screens rebuild through `ListenableBuilder(listenable: Depo.i)`. There is no backend and no user data is uploaded; the only outbound requests are the data update, the news search and the weather lookup described below.
- Data loading prefers a downloaded copy in SharedPreferences (`veri:<file>`) over the bundled asset. `Depo.guncelle()` fetches `surum.json` from `veriAdresi` (`veri/ayarlar.dart`, empty until a repo is published), downloads files whose hash changed, verifies SHA-256, then reloads. A new data file must be added to `veriDosyalari` in `ayarlar.dart` or it is never updated.
- Legislation library (`ekranlar/mevzuat.dart`): `Depo.kitaplik` is the index; a text's articles load lazily through `Depo.mevzuatMaddeleri(kod)` and `Madde.arama` is computed on first use, so startup does not pay for ~1,500 articles. `Depo.maddeler` still holds only 2918 and 4925 and is what the assistant searches. Library file names come from the index, not `veriDosyalari`; updated copies are stored in a Hive box (too large for localStorage on web), tracked by the `kitaplikGuncel` pref. The screen's search box runs over every text and the fine guide.
- News (`veri/haberler.dart`, `ekranlar/gundem.dart`): the list comes from `haberler.json`, merged with a direct Google News RSS search done on the device (`Depo.haberleriYenile`) and cached under `haberOnbellek`. The direct search is skipped on web (`kIsWeb`) because of CORS. Its keyword filters duplicate the ones in `tarayici/haberler.py`; change both together.
- Weather (`veri/hava.dart`, `ekranlar/hava_karti.dart`): Open-Meteo forecast and geocoding, no API key. Coordinates are rounded to two decimals (about 1 km) before being sent; keep that. `yolUyarilari` turns conditions into enforcement-relevant warnings, and the last response is cached in the state blob for 20 minutes.
- Accident records (`Depo.kazaKayitlari`, `ekranlar/kaza_kaydi.dart`) are the user's own field notes with optional GPS position (`geolocator`, helper in `ek_araclar.dart`) and a weather snapshot. They are unrelated to the teaching scenarios in `icerik.json`.
- Accident photos (`veri/foto_deposu.dart`): bytes live in a Hive box on the device (IndexedDB on web); the record only holds their ids in `fotolar`. They must never leave the device: no upload, share, export or download path, and they are not part of the copied record text. Photos are downscaled on pick (which also strips EXIF). Deleting a record deletes its photos; photos added in an edit session that is abandoned are removed on dispose.
- `veri/hava.dart` — weather from Open-Meteo (no key; free tier is non-commercial, CC BY 4.0 attribution shown in Profil). This is the only user-related data that leaves the device: coordinates are rounded to 2 decimals before sending, and the UI discloses it. Live traffic is not embedded (no free data source); the home card deep-links to Google Maps' traffic layer at the selected place and to the KGM road-works page of that province's regional directorate (`_kgmBolgeleri`, taken from the "Genel Bilgi" text of KGM's regional pages). `HavaKarti` and `GundemOnizleme` sit in the home page as `const` widgets, so they listen to `Depo.i` themselves; a const child of the page's `ListenableBuilder` is not rebuilt otherwise.
- `veri/hesap.dart` — calculators. Speed tiers and overload tiers are read by regex from the fine items' own text (`51-2-a-*`, `51-2-b-*`, `65-1-b-*`), and tiered amounts from `cezaMetin`, so calculators follow data updates without code changes. Keep it that way rather than hardcoding amounts.
- Tachograph tiers are the exception: `TakografTuru` hardcodes the regulation limits (4.5 h / 9 h / 90 h, Karayolları Trafik Yönetmeliği md. 98) and the `49-3-*` item ids per tier, because the fine text only says "limit set by the regulation". Amounts still come from data.
- Enforcement records (`Depo.islemler`, `ekranlar/islemler.dart`) snapshot article, text and amount at save time so later data updates do not rewrite history.
- `veri/asistan.dart` — the on-device Q&A engine (not an LLM). Intent handlers run in order (article reference, speed, alcohol, points, payment, fault, general); the general path is an IDF-weighted stem match over fine items and articles with a colloquial-to-statute synonym map (`_esAnlam`) and a coverage threshold that makes off-topic questions return "not found" instead of a guess. Answers must be built only from loaded data. Replies are written in a conversational tone and carry a separate `Cevap.yorum` (the assistant's own opinion, shown in a labelled "Benim yorumum" box): hand-written per-topic opinions in `_konuYorumlari` plus remarks derived from the item's data. Keep amounts, points and legal rules out of the hand-written opinions; any number in a comment must be computed from data.
- `ekranlar/` — one file per bottom-nav area; `ortak.dart` has shared widgets and navigation helpers. Each tool's icon, accent colour and description live once in `aracGorunumu` (`araclar.dart`), keyed by the page title; the tools grid, the `AracBasligi` banner and `HesapSayfasi` (which re-themes the page with the accent via `vurguTemasi`) all read from it, so a new tool needs an entry there. `egitim.dart` also contains `SahneRessami`, which draws accident diagrams from the `sahne` description in `icerik.json` (normalised 0–1 coordinates, heading in degrees, 0 = up).

Fine items are addressed as `"<kanun>:<id>"` (e.g. `2918:47-1-b`); ids are slugs of the article number produced by the scraper, so they change if the guide renumbers an item.

Tests in `test/widget_test.dart` load the real bundled data and assert concrete results (specific tiers, assistant answers), so they also act as a regression check on a data refresh. Network code is tested through its pure parts (`rssCoz`, `haberleriBirlestir`, `Hava.fromJson`, `yolUyarilari`) with inline fixtures; tests never make requests.
