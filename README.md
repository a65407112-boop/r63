# R63 GUI v7

R63 GUI is an executor-side **R6-only** visual morph. It keeps the original R6 rig and welds the included custom body meshes to it.

## Run

~~~lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/r63/main/loader.lua?nocache=" .. tostring(os.time())))()
~~~

Use loader.lua, not a copied old hub.lua link. The loader adds a cache-busting query and verifies that GitHub returned v7.

## v7 fixes

- preserves and restores the original classic outfit, face, accessories, body colors and CharacterMesh objects;
- safely cleans an old v5/v6 morph before a reload;
- keeps skin-colored body layers separate from untinted white shirt/pants layers;
- lets transparent clothing pixels reveal the selected skin color;
- resolves classic shirt, pants, T-shirt, face and all rigid accessory categories through HumanoidDescription;
- replaces only accessory categories supplied by custom IDs and preserves the rest;
- removes stale accessory welds, verifies Roblox's new weld and uses attachment/manual fallbacks when needed;
- validates every downloaded mesh by header and exact byte size so a broken cache cannot be reused;
- supports Normal, Faceless and Invisible head modes;
- includes an HSV skin wheel, brightness controls, responsive scaling and auto-reapply after respawn;
- makes hub.lua the only maintained implementation; r63_v6.lua remains a compatibility loader.

Layered clothing is intentionally reported as unsupported. Roblox wrap layers do not conform reliably to this custom R6 morph; classic shirt/pants textures are mapped directly to the mesh UVs instead.

## Requirements

- an R6 character;
- game:HttpGet and loadstring;
- writefile;
- getcustomasset or getsynasset.

makefolder, isfile and readfile are optional. Without makefolder, the mesh cache is stored as flat files.

## Files

~~~text
hub.lua          canonical v7 implementation
loader.lua       always-fresh public loader
r63_v6.lua       backwards-compatible redirect to v7
meshes/          five custom body mesh files
~~~
