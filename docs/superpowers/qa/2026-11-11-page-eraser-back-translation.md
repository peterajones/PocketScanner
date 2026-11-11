# Page eraser: back-translation QA (de, it, zh-Hans)

2026-11-11. FR/ES are reviewed by Peter and are not covered here. Six new strings in
`Localizable.xcstrings` for the page editor's Erase mode (4.1). Each cell is the shipped text, then a
literal English back-translation.

| Key | de | it | zh-Hans |
|---|---|---|---|
| Crop | Zuschneiden → *Trim / crop* | Ritaglia → *Crop* | 裁剪 → *Crop* |
| Erase | Radieren → *Rub out (with an eraser)* | Cancella → *Erase / rub out* | 擦除 → *Wipe out / erase* |
| Undo | Widerrufen → *Undo / revoke* | Annulla ultima → *Undo last* | 撤销 → *Undo* |
| Edit mode | Bearbeitungsmodus → *Editing mode* | Modalità di modifica → *Editing mode* | 编辑模式 → *Edit mode* |
| %lld areas | %lld Bereich / %lld Bereiche → *1 area / N areas* | %lld area / %lld aree → *1 area / N areas* | %lld 个区域 → *N areas* |
| Changing the crop clears the erased areas. | Eine Änderung des Zuschnitts entfernt die markierten Bereiche. → *A change to the crop removes the marked areas.* | Modificare il ritaglio rimuove le aree segnate. → *Changing the crop removes the marked areas.* | 更改裁剪会清除已标记的区域。 → *Changing the crop will clear the marked areas.* |

## Findings

- **Italian Undo is "Annulla ultima", not "Annulla".** Cancel is already "Annulla" in the same
  editor's toolbar; two "Annulla" buttons on one screen would be ambiguous. French has the same
  collision (Cancel is "Annuler"), so the French Undo is "Défaire"; Peter to confirm.
- **German "Radieren", not "Löschen".** Löschen is the app's Delete; Radieren is what an eraser
  does, and matches Apple's Markup eraser (Radiergummi). Zuschneiden matches Photos' crop.
- **Italian "Cancella" does not collide**: Delete is "Elimina" and Cancel is "Annulla".
- **"Erased areas" became "marked areas" in all three.** When the note shows, nothing has been erased
  yet, only marked; "marked" is the accurate word and reads naturally. Meaning unchanged.
- **zh-Hans plural has "other" only**, like the existing "%lld pages".
- **German uses no pronoun** in the note, so the app's du-form is not in play.

`scripts/verify-localization.py` passes.
