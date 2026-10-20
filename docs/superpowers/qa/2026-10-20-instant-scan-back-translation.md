# Instant Scan de/it/zh-Hans — Back-Translation QA Record

**Date:** 2026-10-20
**Scope:** every new user-facing string in the Instant Scan feature, in German, Italian and
Simplified Chinese: the Tips entry, "Saving…", the Scan Document App Intent strings (title,
parameter, target), the two App Shortcut phrases and short title, and the Control's label,
gallery name and description. Spanish and French were reviewed by Peter (signed off
2026-10-20) and are not back-translated here.
**Precedent:** `2026-09-25-de-it-v3.8-release-notes-back-translation.md` and
`2026-09-25-zh-Hans-back-translation.md`.

Method as before: each value translated back to English independently and compared with the
source. As recorded in the zh-Hans pass, nobody on this project can read Chinese, so for that
language back-translation is weaker evidence than for German and Italian.

---

## Mechanical checks

| Check | Result |
|---|---|
| Coverage in all five languages, all three catalogues (app, InfoPlist, Controls) | `verify-localization.py` |
| The tip's quoted Siri phrase equals the App Shortcut phrase, per language | matches (see below) |
| Control and setting names in the tip match the app's own terms | matches (see below) |
| Brand name preserved as Latin "Pocket Scanner" | yes, all strings |

---

## Back-translation

### Tip title: "Scan in one press"

| | Value | Back-translation |
|---|---|---|
| de | Mit einem Tipp scannen | "Scan with one tap" |
| it | Scansiona con una pressione | "Scan with one press" |
| zh-Hans | 一键扫描 | "One-key scan" |

Accurate. The German says *Tipp* (tap) rather than *Druck* (press); that is the idiom German
users expect from iOS and is true for the Control and the Lock Screen, so I kept it.
一键 is the standard idiom for "one press / one click".

### Tip body

Source: "Add Scan Document to the Action button, Control Center or the Lock Screen, or say “Scan
with Pocket Scanner” to Siri. The camera opens straight away and the scan saves to Main Library."

**de:** *Füge „Dokument scannen“ zur Action-Taste, zum Kontrollzentrum oder zum Sperrbildschirm
hinzu oder sage zu Siri „Mit Pocket Scanner scannen“. Die Kamera öffnet sich sofort und der Scan
wird in der Hauptbibliothek gespeichert.* → "Add 'Scan Document' to the Action button, Control
Center or lock screen, or tell Siri 'Scan with Pocket Scanner'. The camera opens immediately and
the scan is saved in the Main Library." Accurate. *Action-Taste*, *Kontrollzentrum* and
*Sperrbildschirm* are Apple's German terms. The quoted phrase is identical to the shortcut phrase.

**it:** *Aggiungi "Scansiona documento" al tasto Azione, al Centro di Controllo o alla schermata
di blocco, oppure di' a Siri "Scansiona con Pocket Scanner". La fotocamera si apre subito e la
scansione viene salvata in Libreria principale.* → "Add 'Scan Document' to the Action button,
Control Center or lock screen, or tell Siri 'Scan with Pocket Scanner'. The camera opens right away
and the scan is saved in Main Library." Accurate. Apple's Italian terms for all three controls.
*Libreria principale* matches the existing "Main Library" key. Straight quotes follow the
existing Italian Signature tip.

**zh-Hans:** *将“扫描文档”添加到操作按钮、控制中心或锁定屏幕，或对 Siri 说“用Pocket Scanner扫描”。
相机会立即打开，扫描件将存储到主资料库。* → "Add 'Scan Document' to the Action button, Control Center
or Lock Screen, or say 'Scan with Pocket Scanner' to Siri. The camera opens immediately, and the
scan is saved to the Main Library." Accurate. 操作按钮, 控制中心 and 锁定屏幕 are Apple's own terms;
存储 and 主资料库 follow the existing catalogue. The quoted phrase matches the shortcut phrase
exactly, including no spaces around the brand name.

### "Saving…"

| | Value | Back-translation |
|---|---|---|
| de | Wird gespeichert… | "Being saved…" |
| it | Salvataggio in corso… | "Saving in progress…" |
| zh-Hans | 正在存储… | "Currently saving…" |

All accurate progress forms. German *gespeichert* rather than *gesichert* because *sichern* reads
as "back up" in Apple's German.

### App Intent strings

| English | de | it | zh-Hans |
|---|---|---|---|
| Scan Document | Dokument scannen | Scansiona documento | 扫描文档 |
| Target | Ziel | Destinazione | 目标 |
| Scanner | Scanner | Scanner | 扫描仪 |

Back-translations: "Scan document", "Target / Destination", "Scanner". All exact. "Scan Document"
reuses the existing key already shipped for the + menu, so the Shortcuts app and the menu agree.
*Scanner* is identical to English in de and it (the same word; allowlisted in the verifier).
*Destinazione* is a little weightier than "Target" but is the standard Italian parameter label;
the user rarely sees this parameter.

### App Shortcuts

| | Phrase 1 | Phrase 2 |
|---|---|---|
| en | Scan with ${applicationName} | Scan a document with ${applicationName} |
| de | Mit ${applicationName} scannen | Ein Dokument mit ${applicationName} scannen |
| it | Scansiona con ${applicationName} | Scansiona un documento con ${applicationName} |
| zh-Hans | 用${applicationName}扫描 | 用${applicationName}扫描文档 |

Back-translations are exact, word for word. Both are natural spoken imperatives, which is what
Siri matches. The `${applicationName}` placeholder is intact in all six values. Short title
"Scan Document" is as above.

### Control

| | Label / gallery name | Description |
|---|---|---|
| en | Scan Document | Open Pocket Scanner straight into the camera. |
| de | Dokument scannen | Öffne Pocket Scanner direkt in der Kamera-Ansicht. |
| it | Scansiona documento | Apri Pocket Scanner direttamente sulla fotocamera. |
| zh-Hans | 扫描文档 | 打开 Pocket Scanner 并直接进入相机。 |

---

## Flagged and fixed

### German control description

The shipped value was *Öffne Pocket Scanner direkt mit der Kamera.* A reviewer read it as "Open
Pocket Scanner directly with the camera", meaning the camera is the instrument. I agree: *mit*
makes the camera the tool, where the English means the destination. It is now *Öffne Pocket
Scanner direkt in der Kamera-Ansicht.* → "Open Pocket Scanner directly in the camera view." That
carries the "lands in the camera" sense. The Italian (*sulla fotocamera*) and Chinese
(直接进入相机, "go straight into the camera") already express the destination and were left alone.

## Recorded, not flagged

- **Italian "Scansiona documento" drops the article** ("Scan document"), the same shape Apple uses
  for action names; it was already shipped for the + menu.
- **Chinese cannot be verified by anyone on the project**, as recorded in the 2026-09-25 pass. The
  terms here are all either Apple's own or already in the shipped catalogue.
