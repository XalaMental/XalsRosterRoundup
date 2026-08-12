# Xal's Roster Roundup - Changelog

## 1.0.0 - August 12, 2026

---

This one started as something to help a friend. Blinky got thrust into the Guild Master role and has been carrying the whole guild since, and I wanted to build her something that actually made that easier. But the bigger picture is the same as it always is for me: I look for the quality-of-life gaps that other addons only half-cover, and try to build something with a genuinely different angle instead of just another version of the same idea. So this is for Blinky first, but I'm hoping it ends up helping a lot more people than just her.

### 🆕 New
- **Live Guild Roster panel** - right-click the minimap button to open a full roster: a condensed list of Mains on the left, an "Alts" indicator column in the middle, and a detail page on the right for whoever's selected.
- **Automatic guild sync** - your real guild name, Guild Master, and every current member sync in automatically, no manual entry required to get started.
- **Main/Alt linking** - link an alt to its main with a live-filtering autocomplete (type a few letters, pick from the list). Switch which character is "the main" at any time - the old main automatically becomes the new main's alt instead of being left stranded.
- **Two profession fields per character**, each with autocomplete against the real, current profession list.
- **"Reason they're here" tags** - Raid, Dungeon, Achievements, Mounts, Community.
- **New member tracking** - a brand-new member's name shows in orange until you've opened their profile at least once, so nobody gets missed. Confirmed Mains show in green.
- **Guild Master tools** - private per-member notes, an Officer list (a label/color only, no extra permissions), and real Promote/Demote/Kick actions gated to the actual Guild Master, each behind a confirmation popup (Kick behind two).
- **Communication page** - any member can whisper the Guild Master or any Officer straight from the Options window, without digging through the roster.
- **Display & Text customization** - accent color, background color/opacity, and body text font/size/outline, all picked from the Options window (applies after `/reload`).
- **Minimap button** - left-click opens Options, right-click opens the Guild Roster directly.

### ⚙️ Under the hood
- Custom-built, hand-drawn UI throughout (buttons, borders, checkboxes, scrollbar, autocomplete suggestion lists) instead of Blizzard's native widgets, for a consistent look and more reliable rendering across UI scales.
- `luacheck` static analysis wired into the dev workflow to catch typos/dead code before anything reaches in-game testing.
