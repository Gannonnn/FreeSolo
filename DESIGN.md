# FreeSolo — Design Brief

This is the project brief for a 2D climbing roguelike, written by the project owner ("I" below is the owner). Read it at the start of every session. When an open question gets answered, log it under **Decisions log** and update the brief to match.

**Status:** Milestone 2 (a real rock wall, now 7.5×7.5 m for the first crag) is built, with a graphics pass on top. Playtest feedback is in; next up is Milestone 3 after you're happy with the size and look.

## The game

Each run is a series of procedurally generated rock walls that get taller and harder. On each wall you climb hold-to-hold while managing a stamina bar. You find rests (e.g. knee-bars), dodge rockfall, and collect money placed off the efficient line. This is the core decision for the climbing portion of each level: how much money to try and collect without falling to your death.

At the top of each wall is a boss fight. Each level will have a set of possible bosses, and each boss has a set of predetermined routes on a bouldering wall or integrated biome; one of them is used for the fight. Before attempting the boss's climb, the player gets to set their own boulder on the same terrain, with the goal being setting one that fits their run's build. Then the player and the boss switch routes and have to climb each other's.

The holds you set on the bouldering wall are bought from a shop after the first stage, and holds you buy persist across the run as your "rack" (like a deck). Between walls you spend leftover money on stats and pick one rule-breaking relic (e.g. lose your legs but get arm strength past the cap).

## Tech

- Godot 4, latest stable: **4.7.2** as of November 2026 (4.8 is in beta). Upgrade between milestones, never during one.
- GDScript with static typing everywhere. `project.godot` sets the `untyped_declaration` warning to error, so untyped declarations don't compile.
- Primary target: desktop builds (Windows/macOS/Linux). Keep web export working as a secondary target.
  - Use the Compatibility renderer on every platform, so desktop and web draw the same way.
  - Export web builds with thread support off, so they run without cross-origin isolation headers.
- Build as much as possible in code. Keep `.tscn` scenes minimal (a root node plus a script) so the project stays editable as plain text.
- Game logic lives in plain GDScript classes under `res://sim/`.
  - These classes extend RefCounted and never touch Nodes, the scene tree or rendering.
  - This keeps them unit-testable with GUT and lets the boss AI call them directly.
  - The sim advances in fixed steps (`step(dt)` called from `_physics_process`). Inputs are queued and applied on the next step, so the same seed and the same inputs always give the same result.
- Rendering, input and UI live under `res://game/` and `res://ui/`. They only read sim state and send inputs into it.
- Use one RandomNumberGenerator, seeded per run, and pass it into everything that needs randomness. Never use the global random functions: `randi`, `randf`, `randi_range`, `randf_range`, `randfn`, `randomize`, `seed`, and also `Array.shuffle()` and `Array.pick_random()`, which use the global generator.
  - Cosmetic effects (leg shake, particles) use time-based functions, not an RNG, so frame rate can never change a run.
- Walls: the generator (sim) places the rock's features and holds directly, using a RandomNumberGenerator seeded with the wall seed. The rock's relief is render data. `res://game/` bakes heightmaps from the sim's holds and features plus cosmetic noise (FastNoiseLite, seeded from the wall seed), and a shader lights them once, when the wall is built, into plain textures. Nothing in the sim reads the relief.
- Draw the climber's limbs in code with `_draw()` and a hand-written two-bone IK solver (law of cosines). Don't use Skeleton2D.
- Data-driven content: hold types, stats, relics, bosses and tuning numbers live in typed Resource classes or const dictionaries under `res://data/`.
- Art: the rock is 2D lit relief with procedural detail (see Walls). The climber, landscape, ground and UI are still simple shapes drawn in code.
- Tests use GUT 9.7.1 (the release for Godot 4.7), vendored in `res://addons/gut/` and runnable headless from the command line.
- Performance: GDScript is slow at per-pixel loops and allocation-heavy code.
  - Keep `Difficulty.evaluate()` allocation-light, since the boss AI calls it thousands of times per decision.
  - When baking rock relief, only loop over the texels that holds and features cover. Use the engine's native helpers (like `FastNoiseLite.get_image`) for detail over the whole surface, and do the lighting in a shader.
  - The sun never moves, so the rock shader runs once per 8 m chunk, offscreen, with one texel per screen pixel. It runs again if the window's scale changes.
  - A 15–25 m wall currently generates in about 0.3 s, its art bakes in about 0.9 s, and lighting it takes about 0.15 s at 720p (0.27 s at 1080p). The game then runs at about 210–250 FPS at 1080p on an Intel integrated GPU, against about 150 FPS with the shader running every frame.
- Keep every texture under 4096 px on a side (the WebGL limit). Rock relief is baked in 8 m chunks for that reason.
- Godot writes a `.uid` file next to each script. Keep them with the scripts when the project goes into version control.

## Architecture and conventions

- `res://sim/`: pure game logic.
  - `climb_sim.gd` runs one climber on one wall: queued inputs, moves, skill checks, rests, stamina, falls, topping out.
  - `difficulty.gd` is the move model. `body_solver.gd` places the pelvis and torso lean for a set of contacts, `foot_planner.gd` picks footholds, and `ik.gd` is the two-bone solver (also used for drawing).
  - `skill_check.gd` is the deadpoint dial and the dyno meter. `climber.gd`, `body_dims.gd`, `hold.gd`, `rest_spot.gd`, `rock_feature.gd`, `wall.gd` and `move_result.gd` are the data they work on.
  - `wallgen.gd` builds a wall from a `WallSpec` and a seed. `route_finder.gd` is the careful test climber it uses to prove the wall can be climbed.
- `res://data/`: content and numbers.
  - `tuning.gd` holds every tuning number, each commented with what it affects.
  - `stats.gd`, `hold_type.gd`, `rock_type.gd`, `wall_spec.gd`, `relic.gd` and `character_def.gd` are Resource types. `holds/*.tres`, `rocks/*.tres`, `walls/*.tres` and `characters/*.tres` are the content, loaded through `catalog.gd`.
  - `test_walls.gd` is the hand-built Milestone 1 wall, as plain data.
- `res://game/`:
  - `main.gd` boots. `climb_screen.gd` builds the wall and its art once, then owns the sim for each attempt and turns input into sim calls.
  - `rock_relief.gd` bakes the rock's heightmaps, and `water_streaks.gd` paints where water runs down the face. `rock.gdshader` lights them, and `rock_view.gd` runs it once per chunk offscreen and draws the result.
  - `backdrop.gd` (sky and parallax landscape fading into haze), `height_haze.gd` (haze over the ground as you climb), `ground_view.gd`, `wall_view.gd` (hover ring, rest labels, top line), `climber_view.gd` with `soft_shadow.gdshader` (the climber and their soft shadow) and `camera_rig.gd` (preview, then follow) draw the rest.
- `res://ui/`: the HUD, the hover label that names holds, the skill-check dial and meter, and the F1 debug overlay.
- `res://tests/`: GUT tests. `fixtures.gd` builds small walls, climbers and sims.
- Units: meters and seconds in the sim; 100 px per meter on screen (`View.PX_PER_M`).
- Axes: Godot's y-down. A wall's origin is its top-left corner and the ground is at `y = size.y`.
- Angles are radians.
  - Hold rotation 0 faces up (a normal edge), PI/2 faces right (a sidepull, pulled leftward), and PI faces down (an undercling).
  - Wall angle is radians past vertical: negative is slab, positive is overhang.
- Left and right are the climber's own, seen from behind, so they match screen left and right.
- The wall is generated once from its wall seed. Each attempt on it seeds the climb's RandomNumberGenerator with `wall seed + attempt number`, which so far only places deadpoint zones on the dial.

## How to run

- Godot 4.7.2 (portable) is in `%LOCALAPPDATA%\Programs\Godot\`, outside OneDrive so syncing doesn't fight the editor.
- Play: open the project in the editor and press F5, or run `Godot_v4.7.2-stable_win64.exe --path <project folder>`.
  - Options go after `--`:
    - `--seed=N`: the wall seed. Otherwise it's random; the HUD shows it at the bottom right.
    - `--rock=granite` or `--rock=limestone`: overrides the wall's rock type.
    - `--test-wall`: the hand-built Milestone 1 wall instead of a generated one.
    - `--no-preview`: skips the wall preview.
    - `--debug`: the F1 overlay is on from the start.
  - For checking the art without playing: `--screenshot=file.png` saves one frame and quits (`--shot-frames=N` sets how many frames it waits first), and `--look=X,Y,ZOOM` fixes the camera at a spot on the wall, in meters.
    - `--light-bands=N` lights the rock in N flat steps, for a posterized look (see open question 21).
    - `--live-rock` runs the rock shader every frame instead of once. It looks the same in play and is slower, but stays sharp when `--look` zooms in past 1.
- Tests: `Godot_v4.7.2-stable_win64_console.exe --headless --path <project folder> -s addons/gut/gut_cmdln.gd`, or the GUT panel in the editor.
- Export presets exist for Windows, Linux, macOS and Web, but export templates aren't installed yet, so no export has been tried.

## Climber

- Body with two hands and two feet. Limbs are drawn with two-bone IK to their holds.
- Controls (as built; tunable):
  - Left click moves the left hand to the hovered hold; right click moves the right hand.
  - Feet auto-place to the best foothold in range after every hand move.
  - A reach a bit beyond static range is a deadpoint, a Dead by Daylight-style skill check.
    - A dial appears around the target hold and a needle sweeps once around it. Press Space while the needle is in the white zone.
    - The first quarter of the zone is a "great" catch that costs half the stamina.
    - A miss costs stamina, and the hand goes back to its hold.
  - Farther reaches need a dyno.
    - Hold Space to charge a meter that sweeps up and down, point at the target hold, and release inside the green band.
    - Both hands let go. The hand nearer the target catches it, and the other re-grabs with a normal click.
    - A missed dyno is a fall (and a fall is death; see Falls).
    - Horizontal dynos reach farther than vertical ones: that's the main way to dodge rockfall.
  - E rests at a knee-bar. E again, or any hand move, stops resting.
  - Hovering a hold names it and says what each hand would need to reach it: a plain reach, a deadpoint or a dyno.
  - R restarts the attempt on the same wall. F1 toggles the debug overlay. (Gear / G is gone unless a boss reward grants a special rope; see Protection.)
- Stats: fingers, power, endurance, core, footwork. Reach (height/ape index) is fixed per starting character.
- Stamina drains per second based on hold quality, wall angle, feet and stats, and each move costs stamina. At 0 you fall.
- Low-stamina tell: legs shake (below 30% stamina).
- Rests:
  - jug: no recovery, but hanging on jugs drains much less than on worse holds
  - knee-bar spot: refills to 80% of max stamina. Needs specific geometry: the gap from the foothold to the knee spot has to fit your shin.
  - No ledges on walls for now. Later levels can use objects (trees, branches) as full rests instead.

## Move difficulty model (`res://sim/difficulty.gd`): the most important function in the game

- Input: current body position, target hold, hold type and rotation, wall angle, available feet, climber stats and current fatigue.
- Output: whether the move is possible, its type (static / deadpoint / dyno), its stamina cost, and the skill-check window size.
- Must be deterministic and fast; the boss AI will call it thousands of times.
- How it works (Milestone 1):
  - Reach: the body slides toward the target as far as the other hand and the planted feet allow. With no feet on, the supporting arm can only lock off so far.
  - Move type: decided by the distance still left beyond a straight arm. None is static, a little is a deadpoint (more range with power), more is a dyno (less range with no feet), and beyond that the move is impossible.
  - Dyno reach is longer when the target is mostly sideways (for rockfall dodges).
  - Grip: the hold's grip, reduced when the arm pulls away from the direction the hold faces (past its tolerance), plus a fingers bonus on finger-heavy holds.
  - Cost: grows with the distance the hand travels and the move type, plus poor grip, overhang, missing feet and fatigue. Footwork discounts static moves; power discounts big ones.
  - Window: a base size, larger the further inside its range the move is, with better grip and with more power, and smaller when fatigued.
  - Hanging drain: weight on the hands times how poor each hand's grip is. Good feet, footwork and slab take weight off; overhangs put it back unless you have core.

## Walls (`res://sim/wallgen.gd`, drawn by `res://game/rock_relief.gd` and `rock.gdshader`)

- The climbing part of each level is a real rock wall, not a generated route of holds.
- Each level's wall is a `WallSpec` plus a seed. The spec sets the height, width, rock type, steepness, hold density and natural rests. The same spec and seed always give the same wall.
- Sizes per level (height × width): 7.5×7.5, 10×7.5, 15×10, then 20, 30, 40, 50 m tall and so on. Tall walls play the same as short ones (no pitches); the player gets stronger instead.
- What the generator builds, in order:
  - The face: a climbable outline inside the wall's width, with landscape showing around it. The arête rounds away over a short distance; a long fade into haze was tried and dropped (it read as dissolving, not as rock falling back). Real side depth waits on the camera-angle experiments. Bands of slab, vertical and overhang run up it, kept easier near the ground and at the top-out.
  - Features from the rock type: cracks with finger jams, flakes with sidepull edges, horizontal rails of edges, and on limestone, tufas (lines of pinches) and clusters of pockets.
  - Scattered holds in patches, with blank rock between featured areas. Steep rock gets bigger holds and slabs get smaller ones. Foot chips go everywhere, and smears on slabs.
  - Natural rests: knee-bars under the lips of roofs. No ledges.
  - Start holds you can reach from the ground, and holds over the top for the top-out.
- Guaranteed climbable: a careful test climber (the default character) climbs the wall in the real ClimbSim. It prefers static moves and rests when low.
  - Where it gets stuck, the generator adds a hold or a rest at that spot and climbs again, until a climb needs no repairs.
  - That line is kept and shown in F1. Chalk that marks the popular line is planned later (open question 14), not drawn yet.
- Rock types:
  - Granite: edges, crimps, cracks and flakes, grey speckled rock with lichen.
  - Limestone: pockets, tufas and rails, water-worn runnels, orange and blue-grey streaks.
  - More can be added as `.tres` files.
- Drawing:
  - Each hold and feature is carved into a heightmap of the rock, with chalk on handholds and rubber on footholds (ordinary wear, not the proven-line chalk).
  - Ridged noise adds creases and facets. A coarse map adds the big forms: broad bulges and ridges, warped so they don't look like clouds, and grooves along joints that split the face into big blocks. It also rounds off the face's edges and shades the rock under roofs.
  - A shader lights it all:
    - Sun from the upper left with soft cast shadows. It steps toward the sun across the heightmap, so ledges, bulges and roofs shade the rock below them.
    - Ambient occlusion, so cracks and pockets go dark.
    - Cool sky light on up-facing rock and warm light bounced from below on down-facing rock.
  - Color follows the shape:
    - Lichen grows on up-facing rock, dirt collects in crevices, and handholds and footholds get chalk and rubber.
    - Dark water streaks run down from ledges, jugs, cracks, roof lips and the cliff top. They're painted when the wall is built by following where water would run, and drip free under overhangs.
    - Limestone shows its bedding as beds of slightly different shade.
  - The rock is lit once into textures (see Tech). The follow camera stays on whole screen pixels so those textures stay sharp.
  - Behind the cliff are a sky and parallax mountains and hills, fading into haze toward their feet. In front are the ground, and grass and pines along the top. As you climb, the ground fades into haze below you.
  - The climber casts a soft shadow on the rock, away from the sun. Hands and feet on holds touch their shadows; the rest of the body stands off the wall.
- Before climbing, the camera shows the whole wall for a few seconds (any key skips) and flies in to the climber. During the climb it shows about 7 m of wall.
- Holds first, rock carved around them: the generator places features and holds, and the heightmap is carved from them for drawing. Confirmed.
- **Hard-to-spot holds** (design stub): some holds are meant to be easy to miss — same climbing rules, but drawn to blend into the rock (no chalk, quieter carve). Field exists; look and generator placement come later.
- Protection (Milestone 3): none by default. A fall ends the run. Special gear (e.g. an anti-gravity rope) can only come from beating a boss; until then there is no placing protection.
- Money and rockfall (Milestone 3): see open questions 7 and 10.

## Falls and rockfall (Milestone 3)

- Every fall is death, unless a special circumstance says otherwise (a boss reward rope, a scripted beat, etc.).
- Rockfall: the main dodge is a horizontal dyno. Warning dust and a shadow mark the column only a short beat before impact, so the player has to already be ready to move.
- Rock size is random. Compare it to the climber's strength (power / related stats): if the rock overpowers them, they die; otherwise it costs a little stamina.

## Obstacles (later walls)

Later levels get more complicated, with obstacles. They come after Milestone 5, one or two per milestone, starting with the ones that reuse existing systems.

- From my brief:
  - Waterfalls that push you. The holds under the water are wet (less grip), and spray warns you where it falls.
  - Falling rocks. Already planned for Milestone 3, with warning dust and shadows.
  - Slippery ice you have to climb on: low-grip holds and smears, and maybe ice tools later as gear or a relic.
  - Trees in the way that block static reaches and force large dynos. A branch could also be a hold or a rest (standing in for ledges).
- Brainstorm, not decided:
  - Wind gusts that push your body and make dynos drift.
  - Loose rock: holds that break if you weight them too long or too hard, with cracks around them as the tell.
  - Wet streaks after rain, with lower grip along the water streaks.
  - Heat: sunny rock drains grip faster than the shade under roofs.
  - Night or dusk: a headlamp cone limits what you can see.
  - Wide cracks and chimneys that need other techniques (stemming, jamming).
  - Big roofs: a run of near-horizontal climbing.
  - Birds' nests or bees: holds to avoid, or a swarm that chases you off a section.
  - Snow and verglas on high walls, and altitude that lowers max stamina.
  - Storms with lightning that make you hurry.
  - Slippery moss.
  - Mountain goats knocking rocks down.
  - Other climbers above you dropping gear or rocks.
  - Ice falling from above on cold walls.

## Boss fight: route swap (`res://sim/boss_fight.gd`)

- Each level has a set of possible bosses. Each boss has a stat profile and a set of predetermined routes for its arena (a bouldering wall or integrated biome). One route is used for the fight; how it's picked is open question 27.
- The player sets their own boulder on the same terrain with holds from their rack, choosing each hold's position and rotation. Rotation changes a hold's usable direction (crimp → sidepull → undercling).
- While setting, show estimated difficulty for both climbers.
- Then they swap: the player climbs the boss's route and the boss climbs the player's.
- The player performs skill checks; the boss's result is computed with the difficulty model.
- Boss AI: the boss climbs the player's route by searching move sequences with the difficulty model and its stat profile. It doesn't set anything, since its routes are authored.
- Rack / shop (Milestone 4): keep a larger inventory of about 20 gym holds with more defined, more 3D textures, sold on a shop screen before the boss. Details of setting rules otherwise stay on their defaults for now.

## Run loop

wall → route-swap boss → stat shop → pick 1 of 3 relics → next wall (taller, harder, eventually a new rock type)

## Milestones (one at a time; stop after each so I can playtest)

1. Scaffold the project and build the climber controller on a hand-built test wall: hand movement, IK limbs, stamina, one rest type, falling. Add a debug overlay showing reach range and move difficulty for the hovered hold. **Built.**
2. Real rock wall: a generated natural rock face drawn as 2D lit relief (sun with cast shadows, ambient occlusion, a parallax landscape behind the cliff), many natural hold types carved into the rock, two rock types, knee-bar rests, a guaranteed climbable line, and a wall preview. First wall is 7.5×7.5 m. **Built; playtest feedback in.**
3. Falls (death), money, rockfall (horizontal-dyno dodge, strength vs rock size). No gear unless a boss reward.
4. Route-swap boss fight: hold rack (~20 gym holds), route setting with rotation, difficulty preview for both climbers, one boss with a few predetermined routes and a simple climbing AI. Leave open questions for this milestone as they are until we get there.
5. Run loop: shop, stat upgrades, relics, walls of 7.5, 10 and 15 m with a boss after each, win and lose screens.
6. Onward: obstacles for later walls, one or two per milestone (waterfalls, ice, trees and more; see Obstacles).

## Working rules

- Keep the sim/render split strict. A test scans `res://sim/` for node, scene-tree, input and global-random use.
- Write GUT tests (under `res://tests/`) for:
  - `difficulty.gd`
  - wall generation determinism (same seed → same wall)
  - the boss fight logic (setting rules, the win rule, the boss AI's climb)
- Prefer small readable modules over clever abstractions. Comment tuning constants with what they affect.
- If something here is ambiguous, or seems unfun once implemented, flag it instead of silently deciding.

## Changes from the original brief

- The original named `src/sim/difficulty.ts`, `src/sim/wallgen.ts` and `src/sim/addon.ts`, and asked for Vitest tests. Everything else in the brief is Godot, so those became `res://sim/difficulty.gd`, `res://sim/wallgen.gd` and `res://sim/addon.gd`, tested with GUT.
- Pinned versions (Godot 4.7.2, GUT 9.7.1) and added tech rules: Compatibility renderer, web export without threads, fixed-step sim with queued inputs, the full list of banned global random calls, no RNG in cosmetic effects, untyped declarations as errors, performance notes.
- Otherwise only wording fixes (typos, "the user" → "the player"). No gameplay rule was changed.
- After my boss-format decision (see Decisions log), the add-on section became the route-swap section, `addon.gd` became `boss_fight.gd`, and Milestone 3 and the test list changed to match.
- After the Milestone 1 playtest (see Decisions log), "placeholder art only" became 2D lit relief, wall heights became 25, 35, 50 m and up, an Obstacles section was added, and the milestones were re-planned.
- Walls are built features-first: the generator places holds and features, and the rock's relief is carved from them, instead of holds being derived from a noise heightmap.
- After the Milestone 2 playtest answers (2026-11-13): wall sizes became 7.5×7.5, 10×7.5, 15×10, then 20 / 30 / 40 / 50 m tall; ledges removed; stamina raised; no gear by default; falls are death; rockfall dodge is a horizontal dyno. A side-apron fade into haze was tried and reverted.

## Camera depth (research notes)

Face-on is close to its limit. Keep it for now; later experiment with a slight angle while textures keep improving. Options, cheapest first:

1. **Stay 2D, sell depth in the art** (what we have, plus the side apron): soft shadows, AO, two-tone light, climber contact shadow, haze, and rock that continues past the climbable face and falls back into the backdrop. No camera change; gameplay stays exact.
2. **Fake yaw / shear in 2D:** a small horizontal skew (CanvasItem transform or a post-pass) so vertical edges converge a little, like looking from slightly off-center. Gameplay math stays face-on; only the draw tilts. Risk: holds and the climber can look sheared; the hover pick ray needs the inverse transform.
3. **Orthographic 3D, small yaw:** put the lit rock (or a displaced mesh of it) in a 3D scene with an orthographic Camera3D yawed a few degrees; keep the climber as a billboard or a flat mesh at the wall. Engine depth and side foreshortening come free. Cost: the climber, UI, and input picking have to live in that space; Compatibility renderer still works.
4. **Real displaced 3D cliff:** only if 1–3 aren't enough. Biggest setup cost; sim stays 2D.

Default: finish (1), then try (2) as a toggle before committing to (3).

## Open questions

Flagged instead of decided. Each has a recommended default; anything built on a default says so. Numbers never change: answered questions stay listed as answered, and new questions take the next free number.

### Milestone 1: climber controller

1. **Rests without time pressure.** Answered: nothing stops you resting on a knee-bar for as long as you like until hazards are implemented.
2. **What "current fatigue" means.** Built on the default: fatigue = 1 − stamina ÷ max stamina.
3. **Missed skill checks.** Answered: missed deadpoint costs stamina and the hand goes back; missed dyno is a fall (and a fall is death).
4. **Skill-check input.** Answered: deadpoints use a Dead by Daylight dial (press Space in the zone); dynos use a hold-Space meter. Keeping this system; see Q8 for the dyno window and possible alternatives.
5. **Camera angle.** Answered: stay face-on for now; we're near the limit of what it can do. Later, experiment with a slight angle (see Camera depth). Wall angle already shows in the lighting and the side-profile strip.
6. **Rests.** Answered: knee-bars only on walls for now (refill to 80%). Remove ledges; later levels can use objects like trees as full rests. Max stamina raised about 15%.
7. **"Great" deadpoint catches.** Answered: keep them. Fun timing nuance is welcome.
8. **Skill-check timing.** Deadpoint window is about right. Dyno window was too short — widened. Still open: is there a better dyno check than hold-and-release Space? Candidates: the same dial as deadpoints; click the target hold on the beat; a short mouse flick toward the hold when the cue hits. Default for now: keep the meter, with the wider band.
9. **Reach vs. hold spacing.** With good feet, a static reach gets about 0.45 m above your higher hand. Holds alternating hands every ~0.38 m are mostly static moves; skipping one needs a deadpoint or a dyno. The generator spaces holds along features 0.28–0.42 m apart to match.
10. **Resting on ledges.** No longer applies: ledges are removed from walls.

### Milestone 2: real rock wall

11. **Limited view.** Answered: camera distance is good for now (~7 m of wall at 720p).
12. **Holds first, rock carved around them.** Answered: keep it. Good design philosophy.
13. **Reading natural holds.** Answered: no hold outline key. Textures and 3D read have to make ordinary holds obvious. Separate feature: **hard-to-spot holds** — designed to blend in; stub only for now (`Hold.hard_to_spot`).
14. **Chalk on the proven line.** Answered: like the idea; leave unimplemented for later. Ordinary chalk/rubber wear on holds can stay.
15. **How many rests.** Answered: about right as built (knee-bars only).
16. **Repairs that look placed.** Repair holds and knee-bars go exactly where the test climber needed them, so a few may sit in odd-looking spots. Default: fine for now. Later, repairs could extend a nearby feature instead.
17. **Smears and the ground.** Answered: fine. Manual feet would be too tedious.
18. **Gym holds.** Answered: keep a larger inventory of about 20 gym holds with more defined, more 3D textures for a shop screen before the boss (Milestone 4). The hand-built test wall stays behind `--test-wall`.
19. **Wall sides / free-standing tower.** Tried a soft apron that faded into haze — it read as dissolving, not as rock falling back. Reverted to a short arête round. Real side depth belongs with the slight camera-angle experiments (Q5).
20. **Tall walls.** Per 8 m of wall, the rock's heightmaps take about 7 MB of video memory and the lit rock another 6 MB at 720p (13 MB at 1080p). A 100 m wall would need about 160–250 MB, and generating, baking and lighting take longer the taller the wall. Default: fine for early walls. For the web build or taller walls, only bake and light the chunks near the camera.
21. **Posterized light.** Leave as is until playtested (`--light-bands=N`, off by default).
22. **Strata.** Built as shade only on limestone; ledges come from features (and no rest-ledges). Default: keep it this way.

### Milestone 3: falls, money, rockfall

7. **Dodging rockfall.** Answered: horizontal dyno is the main dodge. Short warning only. Rock size is random; if it overpowers the climber's strength they die, otherwise a small stamina hit.
8. **Where gear goes.** Answered: no gear on walls unless you earn something like an anti-gravity rope from a boss. First wall was too tall at 25 m — sizes are now 7.5×7.5, 10×7.5, 15×10, then 20 / 30 / 40 / 50 m tall.
9. **After a fall.** Answered: every fall is death unless a special circumstance says otherwise.
10. **Money.** Default: coins sit on holds and are collected on hand contact. The "efficient line" is the cheapest path through the holds according to the difficulty model; coins go on holds a few moves off it.

### Milestone 4: route-swap boss

Leave these unaffected for now (defaults stand until we get here).

12. **Which boss format?** Answered: route swap, with the boss's route picked from predetermined ones (see Decisions log).
13. **Route-swap win rule.** Replaces the add-on's letters question. Default: you win if you top the boss's route and the boss fails yours. A tie (both top, or both fail) replays the fight with another of the boss's routes, and you may re-set yours; this is the brief's "resetting each time there is a tie". After three ties, whoever got higher on their last attempt wins.
14. **Losing a boss.** Run over, or a penalty (lose money, skip the relic)?
15. **Arena terrain and feet.** "Blank wall" vs. "same terrain / integrated biome". On a blank wall, where do feet go? Default: each arena is a fixed terrain with a fixed grid of small foot chips both routes share, and the boss's authored routes are built on it.
16. **Boss skill checks.** Default: deterministic. The boss passes a skill check when the move's window is at least the boss's skill threshold, so the setting preview can show the boss's result exactly, which makes setting tactical.
17. **Repeating the sequence.** No longer applies: it was about re-climbing the add-on's growing sequence.
18. **Setting rules.** Default: every rack hold is available while setting, each used once. A route has a start and a finish and at most ~8 holds. You must be able to climb your own route (the difficulty model has to find a path for you), so you can't set an impossible one. Rotation snaps to 45° steps. (Rack size / shop inventory: see Milestone 2 Q18 — about 20 gym holds.)
19. **Hold shop.** The run loop only lists a stat shop. Default: one shop after each boss sells stats and holds; the first boss uses a starter rack.
27. **How the boss's route is picked.** Default: drawn from the run RNG when the fight starts.
28. **Who sees what, and in which order.** Default: you see the boss's route, and can preview it with the difficulty model, before you set yours. Then you climb the boss's route, then watch the boss climb yours.
29. **Stamina between the two climbs.** Default: both climbers start each climb fresh.

### Milestone 5: run loop

6. **One RNG vs. repeatable seeds.** If one RNG feeds everything, wall 2's layout depends on how wall 1 was played (rockfall and the boss AI draw numbers too), so sharing a seed won't reproduce a run. Default: at run start, the run RNG draws a seed for every wall and boss, and each system seeds its own RandomNumberGenerator from those. Everything is still determined by one run seed, but this bends the "one RNG" rule. Walls already work this way: they're generated from their own wall seed.
20. **Stat scale.** Default: integer levels 1–10; relics can raise a stat's cap.
21. **Relics that counter terrain.** "No legs" is great on overhangs and close to impossible on slabs. Default: the relic screen shows the next wall's rock type and angle profile.
39. **A stronger powerup each stage.** Is that the relic pick getting stronger each stage, or a separate powerup on top of the relic? Default: relics come in tiers, and each stage's pick offers the next tier up.

### Later: obstacles

40. **Which obstacle first?** Default: rockfall in Milestone 3 as planned, then wet streaks and waterfalls (they reuse grip and stamina), then ice, then trees (they need new dyno rules around branches).

## Decisions log

Record each answered question here with its date, then update the brief above.

- 2026-11-03: Approved the folder structure and the data types for Hold, Climber, Stats, Wall and Relic. Milestone 1 started.
- 2026-11-03: Environment: portable Godot 4.7.2 in `%LOCALAPPDATA%\Programs\Godot\`, outside OneDrive. No git for now.
- 2026-11-03 (Q4, skill-check input): "each deadpoint should be a skill check like they have in Dead By Daylight", timed with a Space press. Built as a dial with a sweeping needle around the target hold. Dynos keep the hold-Space power meter.
- 2026-11-03 (Q3, missed skill checks): "missed deadpoint is stamina, missed dyno is fall". A missed deadpoint also puts the hand back on its hold.
- 2026-11-03 (Q1, rests): "let a knee bar refill 80% and a ledge 100, jugs should take less stamina but not refill any".
- 2026-11-03 (Q12, boss format): "Route swap but each boss route will be chosen from a set of predetermined ones". The add-on format is dropped.
- 2026-11-09 (Milestone 1 playtest): the face-on wall had no sense of depth; holds need more variety and more detailed textures; and the climbing part of each level is "a real rock wall, not a generated route of holds".
- 2026-11-09: depth comes from 2D lit relief (chosen over 3D). Detail is procedural: holds are carved into the rock and lit with it, each rock type has its own look, handholds get chalk and footholds get rubber marks. This replaces "placeholder art only".
- 2026-11-09: wall heights grow per level: 25, 35, 50, 70, 95, 125 m and so on. Tall walls work the same as short ones (no pitches); the player gets stronger, and gets a stronger powerup after each stage.
- 2026-11-09: later levels add obstacles: waterfalls that push you, falling rocks, slippery ice to climb on, trees in the way that force big dynos, and other ideas (see Obstacles).
- 2026-11-09: milestones re-planned. Milestone 2 is the 25 m real rock wall; gear, falls, money and rockfall move to Milestone 3; the boss fight is Milestone 4; the run loop is Milestone 5; obstacles come after.
- 2026-11-11: a graphics pass before Milestone 3, so the wall reads as 3D, biggest wins first:
  - soft cast shadows, ambient occlusion, and two-tone ambient light;
  - color from shape: lichen, dirt, water streaks and chalk;
  - rock-shaped noise: ridged and warped forms, cellular crack networks, and strata;
  - holds carved into the heightmap;
  - a soft climber shadow;
  - parallax layers fading into haze, and the ground fading into haze as you climb;
  - bake the rock once if it runs heavy on a laptop GPU, and use a real 3D mesh only if the shader isn't enough (it was enough).

  Built as described under Walls, except for open questions 21 and 22.
- 2026-11-13 (Milestone 2 playtest answers):
  - Sizes: 7.5×7.5, 10×7.5, 15×10, then 20 / 30 / 40 / 50 m tall (25 m was too big for the first wall; 15 m still felt large).
  - Q3–4: keep the current skill-check system.
  - Q5: face-on is near its limit; later try a slight camera angle (see Camera depth).
  - Q6: remove ledges; knee-bars only; +15% max stamina. Trees/objects can be rests later.
  - Q7: keep great catches.
  - Q8: deadpoint window is fine; widen the dyno window. Still open whether dynos should use a different check than hold-Space.
  - Q11: camera distance good.
  - Q12: holds-first confirmed.
  - Q13: no hold outlines; textures must sell ordinary holds. Add hard-to-spot holds as a future feature (stub only).
  - Q14: proven-line chalk later; leave unimplemented.
  - Q15: rest count is about right.
  - Q17: smears/ground OK; no manual feet.
  - Q18: ~20 more-3D gym holds for a pre-boss shop.
  - Q19: side-apron fade into haze tried and reverted; keep the short arête until camera-angle work.
  - Q21: leave posterized light alone for now.
  - M3 Q7: rockfall dodge = horizontal dyno; short warning; rock size vs strength (kill or small stamina).
  - M3 Q8: no gear unless a boss reward (e.g. anti-gravity rope).
  - M3 Q9: every fall is death unless a special circumstance.
  - Milestone 4+ open questions left as they are.
