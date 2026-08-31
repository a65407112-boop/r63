# R63 GUI

A small R6 morph GUI that:

- downloads the included custom body `.mesh` files;
- applies them as `CharacterMesh` objects so classic shirt/pants mapping can remain on the R6 morph;
- accepts comma-separated Roblox asset IDs;
- supports classic `Shirt`, `Pants`, `ShirtGraphic`, `Accessory` / legacy `Hat`, and `BodyColors` objects returned by `game:GetObjects`;
- can reapply the morph after respawn.

## Repository layout

```text
R63-GUI/
├─ hub.lua
├─ loader.lua
└─ meshes/
   ├─ torso.mesh
   ├─ leftarm.mesh
   ├─ rightarm.mesh
   ├─ leftleg.mesh
   └─ rightleg.mesh
```

## GitHub setup

1. Create a GitHub repository.
2. Upload **the contents of this folder to the repository root**.
3. Edit only these two lines in `loader.lua`:

```lua
local GITHUB_USERNAME = "YOUR_USERNAME"
local GITHUB_REPOSITORY = "YOUR_REPOSITORY"
```

4. Commit the changes.
5. Run your raw `loader.lua` through your executor, for example:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPOSITORY/main/loader.lua"))()
```

## Usage

- Character must be **R6**.
- Click **Apply R63 body meshes** to apply the included morph.
- Put IDs in the text box separated by commas:
  `123456789, 987654321, 555555555`
- Click **Apply IDs** for clothing/accessories only.
- Click **Apply all** to apply the body first and then the IDs.
- **Auto reapply on respawn** reapplies the current morph after respawn.

## Executor requirements

The script needs an executor with:

- `game:HttpGet`
- `writefile`
- `getcustomasset` or `getsynasset`

`isfile`, `readfile`, and `makefolder` are optional but improve caching.

## Note about classic clothing

The script uses `CharacterMesh` instead of replacing the R6 limbs with unrelated `MeshPart` instances. This is intentional: it keeps the character as R6 and gives classic shirts/pants the best chance to use the morph's expected UV mapping.
