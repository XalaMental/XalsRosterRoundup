# Xal's Roster Roundup - Changelog

## 1.0.2 - August 12, 2026

I realized limiting all the editing tools to just your literal Guild Master character would really cut into how useful this addon actually is day-to-day. Most Guild Masters aren't logged into that specific character every time they think of a note to jot down or a nickname to add - so this update links your other characters in, too: if you've set one up as your Guild Master's alt, it can now open those same notes and tools without you having to remember to swap over. Hopefully this ends up being a well-received, genuinely needed addition rather than just a nice-to-have.

### 🆕 New
- **Member search** - a search box above the Mains list on the left. Start typing a name (or nickname) and the list narrows to matches instead of you having to scroll through the whole roster.
- **Guild Master alt access** - if you've linked one of your other characters as your Guild Master's alt, that character can now open the Guild Master notes, nicknames, and Officer tools too - no need to log onto your actual Guild Master character just to jot something down. Real guild actions (Promote/Demote/Kick) still only work on your actual Guild Master character - that's a WoW server restriction, not something any addon can get around.

### 🔧 Fixed
- The "+Add Alt" autocomplete suggestion list - clicking a name in it wasn't actually selecting it, so you couldn't add an alt at all.
- The Guild Master notes field is now a real scrollable paragraph box instead of a single cramped line - it grows with what you type and scrolls for longer notes.
- A profile page with everything showing (notes, officer tools, promote/demote/kick) could spill its bottom buttons out past the window's edge. The detail pane now scrolls (same style scrollbar as the member list) instead of just being a bigger fixed box, so this can't happen again no matter how much is on the page.
- Removed the "Linked Main" dropdown from an alt's profile page - it was redundant (you already know who it's linked to by how you got there) and wasn't selectable anyway.
- Clicking a Main's "Alts" button a second time now closes back to their own profile instead of just sitting there.

### ⚙️ Under the hood
- Added a note on the Data page's per-character storage toggle explaining that turning it on removes this alt access, since it needs every character on the account sharing the same roster.
