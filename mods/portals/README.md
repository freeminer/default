# Deep cave portals

Build a vertical obsidian rectangle **4 nodes wide × 5 nodes high**, including
corners, with a **2 × 3 air opening**. Both X and Z orientations work. Placing
the final frame block starts a cave search and automatically lights both ends
when a destination is found. Generated cave frames use `default:obsidian_block`.
Both obsidian and obsidian-block frames are recognized, including older portals;
reconnecting preserves existing frame materials. No ignition item or Nether mod
is required.

Upward-travel surfaces have a slightly cooler violet-blue tint; downward-travel
surfaces remain purple. Existing surfaces update when their portals are processed.

Walk into the opening or drop an item through it. Players and physical Lua
entities travel both ways, with a four-second cooldown. Loaded portals check
for travellers every 0.1 seconds and restore tracking when their blocks load. Entity velocity is
preserved. Links are stored in node metadata and survive server restarts.
Breaking either frame extinguishes the linked openings when loaded; frames
remain. Rebuilding at the same position and orientation checks the saved partner
first and relights both ends if its frame survives and protection allows it.
Pair history persists in mod storage even after both openings disappear. Surviving
old portal metadata is migrated when loaded. Inactive legacy frames without any
history can also be recovered if found within the normal cave search regions.
Changed or dismantled destination frames fall back to a new cave search. Existing frames can be activated by replacing one obsidian block.

Destination frames sit one node above the cave floor, preserving the stone
underneath. Destinations require an empty cave with solid stone footing and clear space on
both sides. The mod does not excavate caves. It checks protection at every
node in the destination volume and source frame using the builder's name.
Travel also checks protection at the entry and arrival using the traveller's
name (the builder's name for items). Protection is provided by the server's
`core.is_protected` implementation.

Settings in `luanti.conf` (also available in the settings menu):

```
portals_y_offset = 30000
portals_y_radius = 250
portals_xz_offset = 10000
portals_search_radius = 128
portals_search_attempts = 24
portals_search_timeout = 180
```

New obsidian-frame searches center on **source frame Y minus 30000**;
obsidian-block frames search at **source frame Y plus 30000**, within ±250 nodes.
Generated lower frames use obsidian blocks; generated upper frames use obsidian.
Upper destinations can stand on safe solid ground such as soil, with clear
space for the frame. Lower destinations still require stone cave footing.
For example, an obsidian frame at Y=1000 searches near Y=-29000; an
obsidian-block frame at Y=-29000 searches near Y=1000. The offset and vertical
radius are configurable. World bounds come only from the server's `mapgen_limit`,
including worlds larger than 31000 nodes. The old `portals_y_min` / `portals_y_max`
settings are no longer used. A target entirely outside the world bounds fails with
a message. Existing saved links still reconnect to their previous destination.
The complete destination frame lies within the resulting Y range. Search
regions are emerged asynchronously without changing mapgen. Frame orientation
selects the horizontal offset axis perpendicular to its surface: a frame spanning
X shifts 10000 nodes on Z; a frame spanning Z shifts 10000 nodes on X.
Portal coordinates determine the offset sign. A direction crossing the world boundary is reversed. The local
`portals_search_radius` applies around that shifted position. Set
`portals_xz_offset = 0` to search near the source X/Z.
A private RNG seeded from the frame coordinates selects the same sequence of
regions on retries and restarts with the same settings. The chosen cave can
still differ if loaded terrain or protection changes.
Search reports progress every ten seconds and stops after the configured total
timeout, even if an emerge callback never arrives. It inspects safe loaded cave
space while other blocks are still emerging. If no suitable cave is found, a
chat message explains how to retry. Increase the range or attempts for worlds with sparse deep caves.

Avoid enabling another mod that ignites obsidian frames, such as Nether, at the
same time. Those mods may claim the same frame.

Run the mocked regression checks from the engine repository root:

```
lua games/default/mods/portals/tests/portals_test.lua
```

Design references: the local Nether mod (frame/link handling) and
minetest-meseportals (player and physical-entity traversal). No media or source
blocks from those mods are bundled; the portal texture uses default obsidian.

Liquid transfer is enabled by default (`portals_transfer_liquids = true`). Source
and flowing liquids touching either face of an opening move to the matching cell
on the opposite face of the linked portal, **one node lower**. Transfer requires
a loaded air destination and protection permission for the portal owner at both
positions. The original liquid node is removed. Transfers preserve node name and
parameters, metadata fields (including private flags), inventory lists and stack
metadata, inventory grid widths, and node timer timeout/elapsed state. The engine
metadata-table extension stores private field names in `private_fields` and list
widths in `inventory_widths`; applying this update requires the rebuilt engine.
Transfers avoid construction/destruction callbacks and roll back failed state
copies. Normal lighting and liquid simulation still update nodes afterwards.
Data a mod stores separately by world position is not relocated automatically.
A short arrival cooldown prevents immediate transfer back during the same step.
Set `portals_transfer_liquids = false` to disable this behavior.
