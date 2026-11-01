# TODO

_Single source of truth for unfinished work in this project. Tick an item when it is done; the review harness records it and removes the line._

## Next
- [ ] On 2026-11-03, update the v4.0 What's New for the changes since build 39 (the OCR Chinese fix, card scans, and the contextual Main Library tips if they're worth announcing): en whats_new.txt, the other 7 locales (back-translation QA for de/it/zh-Hans), then ASC before submitting (from: docs/WhatsNew-v4.md)
- [ ] On 2026-11-04, bump to 4.0 (40) in the app and Controls targets, archive with everything merged since build 39, and upload (from: docs/WhatsNew-v4.md)
- [ ] On 2026-11-04, select build 40 for v4.0 in App Store Connect and submit for review (from: docs/WhatsNew-v4.md)
- [ ] Release v4.0 manually on Wednesday 2026-11-11, the Featuring Nomination date (from: docs/WhatsNew-v4.md)
- [ ] Push App Store metadata for all locales from marketing/app-store-metadata/ via the App Store Connect API (from: docs/FutureEnhancements.md)
- [x] Add a regression test for OCR language handling: run OCREngine on a Chinese-only page and a mixed English/Chinese page, and assert that the request lists zh-Hans + en-US with automatic language detection on. (from: review harness)
- [x] Check whether the Chinese OCR fix needs to reach the already-submitted v4.0 build, and if so upload a new build; also reconsider other CJK languages (ja, ko, zh-Hant) for recognitionLanguages. (from: review harness)
- [x] Add the contextual Main Library tips (scan in one press, search inside your scans, touch and hold for more) to the v4.0 What's New and the locale translations, if they are meant to be announced. (from: review harness)
- [x] Add a UI or unit test for the contextual tip rules: each tip appears once and until closed, the scan-in-one-press tip is suppressed after Instant Scan use, and the card is hidden while searching in list and grid. (from: review harness)

## Later

## Undecided
