# License

This project uses different license terms for different parts of it. Read the
section that applies to the part you're interested in.

---

## 1. Addon Code and Custom Art (All Rights Reserved)

Applies to all `.lua`, `.toc` files, and every custom asset bundled with this
addon (`Icon.png`, `CFIcon.png`, and the icons in `Textures/`) — everything in
this repository **except** the third-party libraries in `libs/` (see section 2)
and the bundled fonts in `Fonts/` (see section 3).

Copyright (c) 2026 XalaMental. All rights reserved.

This code and artwork may not be copied, redistributed, modified, or reused
in another project, in whole or in part, without explicit permission from
the author. If you'd like to use, adapt, or build on any of it, ask first.

---

## 2. Bundled Third-Party Libraries

This addon bundles the following libraries, embedded under their own
original terms (not the terms above, since this project didn't write them):

*   **`libs/LibStub/`** — LibStub, released into the public domain by its
    original authors (Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel,
    joshborke).
*   **`libs/CallbackHandler/`** — CallbackHandler-1.0, part of Ace3, released
    under the BSD (2-clause) license.
*   **`libs/LibDataBroker/`** — LibDataBroker-1.1. No explicit license
    statement is present in the bundled file; distributed here under the
    standard WoW addon library convention (unrestricted use), matching how
    every other addon that bundles it treats it.
*   **`libs/LibDBIcon/`** — LibDBIcon-1.0. Same note as above — no explicit
    license statement in the bundled file; distributed under the same
    standard community convention.

All four are redistributed here exactly as obtained, unmodified except where
this addon's own changelog notes an explicit version update. See each
library's own file for anything it declares itself.

---

## 3. Bundled Fonts

`Fonts/CustomFont.ttf` (Simply Sans Bold) and `Fonts/FiraSans-Medium.ttf`
(Fira Sans Medium) are licensed under the SIL Open Font License, not the
terms above — see `Fonts/SimplySans-LICENSE.txt` and
`Fonts/FiraSans-LICENSE.txt` for the full text. They're redistributed here
exactly as their own licenses permit.

---

## Summary

| Content | License | Can I fork/reuse it? |
|---|---|---|
| Addon code (`.lua`, `.toc`) | All Rights Reserved | No — ask the author first |
| Custom art (`Icon.png`, `CFIcon.png`, `Textures/`) | All Rights Reserved | No — ask the author first |
| `libs/LibStub/` | Public Domain | Yes — no restrictions |
| `libs/CallbackHandler/` | BSD (2-clause) | Yes — under BSD's terms |
| `libs/LibDataBroker/` | Unrestricted (standard convention, unstated in-file) | Yes |
| `libs/LibDBIcon/` | Unrestricted (standard convention, unstated in-file) | Yes |
| `Fonts/CustomFont.ttf` | SIL Open Font License | Yes — under the OFL's terms |
| `Fonts/FiraSans-Medium.ttf` | SIL Open Font License | Yes — under the OFL's terms |
