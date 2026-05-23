# Groupify — Splash Screen Spec (for Claude Code)

## Goal
Implement **only** the iOS launch screen. Do not modify any other screen.

## Visual reference
- `handoff/splash-reference.png` — rendered preview of the target screen
- `handoff/groupify-mark.svg` — the brand mark as a standalone SVG you can drop into `Assets.xcassets`

## Layout
Everything centered (X and Y) on a pure black background.

| Element | Spec |
|---|---|
| Background | `#000000` (pure black, full bleed) |
| Glow behind mark | Soft radial glow, 360×360 pt, color `rgba(124, 92, 230, 0.35)` → transparent at 65% radius, 12pt blur. Center matches mark. |
| Brand mark | 96×96 pt, see `groupify-mark.svg` |
| Vertical gap mark → wordmark | 22 pt |
| Wordmark | Text "Groupify", SF Pro Display, weight 700, size 36 pt, letter-spacing -1.2 pt, gradient text fill `#FFFFFF` (top) → `#B5A4E6` (bottom) |

**Omit any tagline / caption.** Apple HIG: launch screens should look like the app's first frame, not a marketing intro.

## iOS implementation
- Use a **`LaunchScreen.storyboard`** (the standard iOS launch-screen mechanism — Apple does not run any code on the launch screen).
- Add `groupify-mark.svg` to `Assets.xcassets` as a single-scale vector PDF/SVG image set (Xcode "Preserve Vector Data" enabled).
- Storyboard structure:
  - Root view: background color `#000000`
  - `UIImageView` for the violet glow (center X + center Y to superview). Either pre-bake the glow as a 360×360 PNG with the radial gradient + blur, or use a `CAGradientLayer` with a radial type. Pre-baked PNG is simpler and recommended for a static launch screen.
  - `UIImageView` for the brand mark (96×96, centered, in front of the glow).
  - `UIImageView` for the wordmark — **export "Groupify" as a transparent PNG/PDF** with the gradient already applied (storyboards can't render gradient text on a `UILabel`). Place 22 pt below the mark, centered horizontally.
- Set the launch screen storyboard in the target's General → "App Icons and Launch Screen" → "Launch Screen File".

## Do not
- Do not add animations, transitions, or any runtime code. Launch screens are static — UIKit doesn't execute code on them.
- Do not change `Info.plist` keys other than the launch storyboard reference if needed.
- Do not modify the app icon (separate task).
- Do not change colors elsewhere in the app.

## Acceptance
- App launches → black screen with violet glow → centered Groupify mark + gradient wordmark → seamless transition into first real screen.
- Looks identical on iPhone SE through 15 Pro Max (storyboard auto-centers).

---

**Confirm before editing:** list the files you plan to create/modify, then proceed.
