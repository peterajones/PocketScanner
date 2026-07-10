# Sample documents (print props)

Fake, print-ready documents for shooting the App Preview video. All fictional — no
real names, accounts, or bookings. Themed to match the app's demo content.

| File | Use |
|------|-----|
| `costco-receipt.html` | Receipt — searchable on "Costco"; good for the Search beat |
| `banana-bread-recipe.html` | Recipe — searchable on "banana"; reads well framed |
| `lease-agreement.html` | One-page formal document |
| `travel-itinerary.html` | Denser page (flights + hotel) for scan/annotate |
| `legal-document.html` | **Multi-page** (3 pp.) for the multi-page scan + rotate beats |
| `consulting-agreement.html` | **Official-looking** one-page agreement — corporate letterhead + two signature/date blocks. **Sign + date hero doc.** (Meridian Advisory Group) |
| `offer-of-employment.html` | **Official-looking** offer letter — corporate letterhead + "Accepted and Agreed" sign/date block. Alt sign + date hero. (Northgate Technologies) |

All fictional companies/people (Meridian Advisory Group, Northgate Technologies, Jordan Avery, Taylor Morgan) — no real trademarks, seals, or personal data, so the media stays App-Review-safe. Both are tuned to fit on **one page** including the signature/date block.

## Signatures (`signatures/`)

Fictional signatures for the sign+date shots — no need to use a real one. Each is a
**transparent PNG** of a fictional name rendered in a distinct handwriting/script
font (the same idea as a "typed signature" in DocuSign), black ink, ~1800px for
crisp scaling, slightly tilted for realism:

| File | Name | Font | Pairs with |
|------|------|------|-----------|
| `sig-JordanAvery.png` | Jordan Avery | Snell Roundhand (formal cursive) | Consulting Agreement — Consultant |
| `sig-TaylorMorgan.png` | Taylor Morgan | Bradley Hand (casual) | Offer of Employment — employee accept |
| `sig-MorganEllis.png` | Morgan Ellis | Savoye LET (exec script) | Offer of Employment — VP sign |

They have transparent margins (invisible when placed). To bring one into the app,
print it (prints as black-on-white) and scan it like a real signature — the app's
`SignatureProcessor` crops to the ink automatically. Regenerate from
`../../../<no build step — pure fonts>`; see git history for the render command.
(Legacy: `Peter_Signature.jpg` + public-domain `hancock` / `GeorgeWashington`.)

## Printing

Open each file in a browser and print (Cmd+P) at US Letter, 100% scale, default
margins. They're styled with `@page { size: letter }` and page breaks, so the
multi-page legal doc prints as three sheets.

Print the ones you'll scan live during the take; pre-scan the rest to populate the
library (see the storyboard in `../README.md`).
