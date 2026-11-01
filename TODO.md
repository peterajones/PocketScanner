# TODO

_Single source of truth for unfinished work in this project. Tick an item when it is done; the review harness records it and removes the line._

## Next
- [ ] On 2026-11-03, update the v4.0 What's New for the changes since build 39 (the OCR Chinese fix, card scans, and the contextual Main Library tips if they're worth announcing): en whats_new.txt, the other 7 locales (back-translation QA for de/it/zh-Hans), then ASC before submitting (from: docs/WhatsNew-v4.md)
- [ ] On 2026-11-04, bump to 4.0 (40) in the app and Controls targets, archive with everything merged since build 39, and upload (from: docs/WhatsNew-v4.md)
- [ ] On 2026-11-04, select build 40 for v4.0 in App Store Connect and submit for review (from: docs/WhatsNew-v4.md)
- [ ] Release v4.0 manually on Wednesday 2026-11-11, the Featuring Nomination date (from: docs/WhatsNew-v4.md)
- [ ] Push App Store metadata for all locales from marketing/app-store-metadata/ via the App Store Connect API (from: docs/FutureEnhancements.md)
- [x] Audit the other page-render and thumbnail paths for the same max(1, cap / longEdge) pattern that never scales down. (from: review harness)
- [x] Review the contextual tips (a314f71) for localization: check that the TipKit card strings for 'Scan in one press', 'Search inside your scans' and 'Touch and hold for more' exist in all 8 locales before build 40 is archived on 2026-11-04. (from: review harness)
- [x] Add tests for wallet-card detection and the back-scan flow from 52f3c0a: ID-1 aspect 1.586:1 within 5% in both orientations, a non-card page, a one-page capture versus a two-page capture, and the Continue and cancel-back paths that save the front alone. (from: review harness)
- [x] Check that the new card-scan strings ("Scan the other side?", "Scan Back", "Continue", "Combine as front and back?") exist in all 8 locales, and add the feature to the v4.0 What's New and its translations if it is meant to be announced, before build 40 is archived on 2026-11-04. (from: review harness)

## Later

## Undecided
