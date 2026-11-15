# Xal's Roster Roundup - Changelog

## 1.4.0 - November 15, 2026

I started playing on WoW Forever, and Roster Roundup had a rough time there. My roster filled up with people from guilds I'd left, the guild invite from Recruit Next just got blocked, and a few windows spilled past their edges. So this update is me making it work properly there, and fixing the ugly parts I ran into along the way. Recruiting is now whisper-first, with a little reply box that collects the answers so you can right-click a name and invite from the game's own menu. While I was in there I added a backup page, a bigger activity log, and six skins to pick from. Thanks for being part of the Xal family.

### 🆕 New
- A Recruit Replies box that collects the whispers you sent and every answer. It pops up when someone writes back, and a right-click on a name gives you the game's own menu, including Invite to Guild.
- A Replies card on the Recruitment page, newest first.
- A "Recruit Blacklist: never contact again" entry in the player right-click menu, for the replies the automatic opt-out detection misses.
- Unguilded players you run into (nameplate, target, mouseover) can become recruit candidates, and the class filter shows how many of each class your guild already has.
- A Backup page: a safety copy of your guild data about once a day, one-click restore, and Export / Import.
- A Summary on the Log page with joins and leaves over 7 and 30 days, who left most recently and what rank they held, and an Export you can paste into a spreadsheet. Each member also keeps a history of their rank changes.
- Six skins on the Display page - Crimson, Ember, Bronze, Midnight, Indigo, and the light Parchment.
- WoW: Forever support is being built in, and the addon now loads there.

### 🔧 Fixed
- On Forever, a scrambled roster read no longer fills your roster and log with members from other guilds. Reads that don't match Blizzard's own member count are ignored and tried again.
- Hidden-name rows from Forever are skipped instead of being saved as garbage members.
- Recruit Next on Forever now whispers instead of trying a guild invite the game blocks, and scanned players no longer get a made-up name suffix.
- The What's New window now sizes itself to fit all of its text.
- The Log page's filter buttons no longer run past the edge of their box.
- Typing `/rrroster reset` clears and re-reads your current guild's saved roster, log included.

### ⚙️ Under the hood
- Greys across the Options, Guild, and mouseover windows now follow the chosen skin.
- Added a `/rrroster` check and a `/rrreplies` toggle.

## 1.3.0 - October 24, 2026

1.2.0 got Roster Roundup off the ground, but the more I used it, the more it felt like a collection of pages instead of one tool. So this update is a real rebuild. Recruitment now works the way the best guild-recruiting addons do: scan for unguilded players, whisper and invite them, post your ads, and keep a blacklist, all with one candidate in front of you at a time. Every page got the same bordered-card look as the rest of my addons, and the Guild Master and Officer pages picked up real tools for actually running a guild, including promotion rules, strikes, check-ins for members who've gone quiet, and syncing between officers who have the addon. I also cut the things that weren't earning their spot, like the per-character storage page. Thanks for being part of the Xal family.

### 🆕 New
- Recruitment is now three pages - Search, Ads, and Stats - each with its own Settings link. Scan by level, class, race, and zone, whisper and invite one candidate at a time, post ads on a queue, and keep a blacklist (including players who opt out).
- Officer tools on the Guild Master and Officer pages: a roster overview card, members ready for promotion, strikes, inactive-member check-ins, and Message of the Day and guild info editing. Promotion rules are Guild Master only.
- Officer sync - whenever two officers with the addon are online, shared data syncs on its own.
- Right-click menus on players for inviting and recruiting.
- A settings panel in the Esc menu, and every page now scrolls when it's taller than the window.
- A returning-members filter in the Log, and an asterisk on the roster for members you haven't touched yet.
- Pick any installed font on the Text page, with a size slider and Outline and Shadow options.

### 🎨 Visual refresh
- Every page now uses the same bordered cards as my other addons.
- Mains / Alts is slimmer, with alts side by side and a click-the-name Unlink.
- A new, bigger minimap icon.

### 🔧 Fixed
- The race and class filters now list only real, playable options.
- Message of the Day now allows the full 255 characters.
- The Add Alt list has search and scrolling, and a bigger font.
- Pages no longer jump back to the top when they refresh while you're scrolled down, which made the bottom of the Officer page unreachable.
- The What's New window now fits all of its text.

### ⚙️ Under the hood
- Removed the per-character storage page.
- Bundled LibSharedMedia for the font list.

---

Dedicated to "Blinky" - who got handed the Guild Master role with no warning and has been carrying the whole guild ever since. This one's for her first, and hoping it helps plenty of other Guild Masters too.

## 1.2.0 - September 29, 2026

This one turned into a big update. It started as a look at the visuals, but once I got in there I ended up doing a real overhaul - a handful of new features, and a bunch of fixes aimed at just making the whole thing more pleasant to actually use day to day. Hope you notice the difference. Thanks for being part of the Xal family.

### 🆕 New
- A new Applications page - see each pending applicant's level, class, note, and how long ago they applied, and Accept, Decline, or Whisper them right there. Optionally whispers them automatically the moment you accept, letting them know to check their guild invites.
- One floating icon now appears whenever something needs your attention - a pending application, a new member you haven't reviewed, or a rank change - with its glow colored differently for each (orange/blue/purple), so you know what it is before you even click it. Its size is adjustable on the Display page.
- Added a Rank Changes list to the Guild Master page - catches promotions/demotions another officer made that you might've missed.
- Manual date editing - if the addon never actually saw someone join or get promoted (they were already in the guild, or it happened while you were offline), you can now set Date Joined and Promoted yourself with a real date picker. Added a Birthday field too, since that's never something the game tracks on its own.
- An Officer page, right under Guild Master - new members, rank changes, and the officers list, so officers who couldn't see any of that before can actually use this addon too.
- A real activity log - every join, member who leaves, promotion, demotion, level up, note change, and banned-player rejoin gets its own entry, with search and filters.
- A Ban List on the Guild Master page - flag a name and get warned if they ever show back up.
- The Mains / Alts page is fully built now - a small star marks a confirmed Main, right-click a name to set one, and Add Alt sits right after their name once they are one. Confirmed Mains sort to the top of the list.
- A Recruitment page - scan for unguilded players (works correctly across realms), whisper them, invite them straight to the guild, post recruitment ads to General/Trade, and see your stats for the day/week/month.
- Every message this addon can send - the Recruitment whisper, both Ad templates, and the new "whisper an applicant when you accept them" message - now has Insert buttons for {player}, {guild}, and {guildlink} (your guild's own Discord invite), so you never have to remember how to type them.
- A real resize handle on the bottom-right corner of the main window.
- The sidebar's Discord link is now something your Guild Master sets for your own guild, instead of being hardcoded to mine.
- A mouseover panel - hover any name in Blizzard's own native Guild Roster window for an instant profile card, with a real Custom Notes field you can edit right there, and Add Alt available directly from it too.

### 🎨 Visual refresh
- New title, divider, and border colors throughout, with a proper outer border back on every window.
- Sidebar links now only highlight the page you're actually on, instead of staying lit up all the time.
- Switched the title font to Cinzel Bold and the body font to Inter.
- Removed the Communication page - this addon is mostly a Guild Master tool, and most other members won't have it installed anyway.
- The Display page's Accent Color now defaults to the same color as the rest of the addon instead of a separate orange - the picker still works exactly the same, pick your own color and it still changes everything.

### 🔧 Fixed
- The roster now actually drops members who've left your guild instead of keeping them around forever - if the "new members" count on the Guild Master page looked way too high, this was why.
- Fixed the "new members" count sometimes showing an entirely different guild's numbers than the one you're actually in - if you've ever synced more than one guild, the addon was always reading whichever one got stored first.
- Removed the guild-switcher tabs at the top of the Guild Roster window - since you can only ever be in one guild at a time, it was just clutter. The roster still always follows whichever guild you're actually in.
- Fixed the Accent/Background color swatches on the Display page silently locking in a snapshot the moment you opened it, even if you never touched them.
- Promote/Demote/Kick actually work now - took some digging to land on it, but it needed a specific Blizzard function built for binding a key straight to a macro, not the generic keybind approach.

---

Dedicated to "Blinky" - who got handed the Guild Master role with no warning and has been carrying the whole guild ever since. This one's for her first, and hoping it helps plenty of other Guild Masters too.

## 1.1.0 - September 12, 2026

I hadn't touched this one's look since I first built it, and the rest of my addons have moved on to a new visual style since then - a darker indigo background and a deep orange accent instead of the old bronze-gold and swirl texture. Figured it was time to catch this one up so it actually looks like part of the same family again instead of standing out as the odd one.

Testing the new look turned up a few rough edges I wasn't expecting - old saved settings from before the update were quietly overriding the new colors, the What's New popup was overlapping its own text, and the Options window had a couple of spacing issues along the border. Got all of that sorted before calling this one done.

### 🎨 Visual refresh
- Switched the accent color from bronze-gold to a deep burnt-orange, and the background from a dark swirl texture to a flat dark indigo - matches the current look across all of my addons.
- The background opacity slider on the Display page now matches the new orange accent too.
- Fixed the What's New popup overlapping and stacking its own text instead of reading top to bottom.
- Fixed the Options window's border/footer - the window was slightly too narrow, which pushed the Discord link right onto the edge instead of sitting safely inside it. The footer now also shows your actual installed version instead of being stuck on "v1.0.0."

---

Dedicated to "Blinky" - who got handed the Guild Master role with no warning and has been carrying the whole guild ever since. This one's for her first, and hoping it helps plenty of other Guild Masters too.
