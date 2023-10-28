# CP77-BetterSleeves

![](preview.png)

## About

**This is a Cyberpunk 2077 mod which rolls down Sleeves.**

Are you tired of not being able to roll down your sleeves? Well, now you can!

There are currently 2 mods which already do what this mod does:
- [Sleeves (DJ_Kovrik)](https://www.nexusmods.com/cyberpunk2077/mods/3309)
  - This mod doesn't support Transmog, and a bug that was filed to the author (to report this issue) is currently marked as "Won't fix".
- [JB - Long Sleeves (Jelle Bakker)](https://www.nexusmods.com/cyberpunk2077/mods/987)
  - This one actually works with Transmog, but doesn't have filters for weapons so clipping is a thing.

Other than automatically rolling down your Sleeves (I wish this was a thing IRL), this mod adds some keybinds to do that manually.

You can add filters through the mod's CET UI for weapons and items that you don't want to roll down sleeves for.

### Requirements

- [CET 1.27+](https://github.com/yamashi/CyberEngineTweaks)

### Mod Compatibility

If you're making a mod that adds a piece of clothe which has sleeves, remember to set `renderingPlaneAnimationParam` to `renderPlane`
inside your `entSkinnedMeshComponent`s within your `.ent` file. Otherwise, hands will be drawn on top of it when holding weapons/performing
certain animations.

### Known Issues

**None!**

## Development

To improve your dev experience follow the README in [libs/cet](libs/cet).
