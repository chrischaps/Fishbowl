# Fishbowl

A planted aquarium you look into rather than play. The tank lives through a ten-minute day, from a grey dawn through bright midday light and a warm sunset to the blue of a moonlight LED while the fish sleep. Twenty-one fish of five species each have a name, a temperament and a mood: neon tetras school, corydoras sift the sand, the betta rises to gulp air. You can sprinkle food, tap the glass, or rest the cursor and let the curious ones come to say hello, and the tank remembers how much they have come to trust you.

**Project page:** [chaps.dev/projects/fishbowl](https://chaps.dev/projects/fishbowl/) has a whole day in the tank as one film, clips of feeding time and meeting the fish, and stills from dawn to moonlight.

![The tank at one frozen moment, blended across the glass from dawn at the lower left to night at the upper right](https://chaps.dev/projects/fishbowl/cover.jpg)

## Running it

Fishbowl runs on [LÖVE](https://love2d.org/) 11.4. From the repository root:

```bash
love .
```

| Input | What it does |
|---|---|
| Click | Sprinkle food |
| Right-click | Tap the glass |
| Rest the cursor | Meet a fish |
| T | Skip to the next time of day |
| [ and ] | Slow down or speed up the day |
| R | Follow your real clock |
| M | Mute |
| F12 | Save a picture |
| H | Show the help card |

Developer modes check the tank with no one at the mouse (see the header of `dev.lua`):

```bash
love . --snap sunset 4       # save snaps/sunset.png after 4 seconds, then quit
love . --selftest            # drive every interaction, report, quit
love . --seed 7              # try a different aquascape
love . --script capture.lua  # run a capture or test script
```

Time-of-day names are `dawn`, `morning`, `day`, `afternoon`, `sunset`, `dusk` and `night`. Pictures land in the LÖVE save directory (`%APPDATA%/LOVE/Fishbowl/snaps` on Windows).

## How it's built

The tank is a shallow 3D box: every object has a depth between the back and front glass and is projected toward a vanishing point. Each fish is a spine with real yaw and pitch, skinned as a mesh, so it foreshortens as it turns toward you.

- `fish/` - species, the spine body, and each fish's moods and schooling
- `env/` - day cycle, water, surface, current, plants, driftwood, substrate, glass and motes
- `shaders/` - caustics, god rays, haze, object lighting and the final composite
- `fx/render.lua` - the scene canvas, depth-of-field and post-processing passes
- `audio/ambience.lua` - every sound is synthesized at startup; no audio files ship
- `save.lua` - names, trust and colors kept between visits
- `LoveLibs/` - [LoveLibs](https://github.com/chrischaps/LoveLibs), vendored as a subtree
