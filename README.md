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

- [CET 1.32.0+](https://github.com/yamashi/CyberEngineTweaks)
- [RenderPlaneFix](https://github.com/Marco4413/CP77-RenderPlaneFix) (recommended, dynamically fixes draw order of clothing items)

### What version should I download?

There are currently 3 separate files:
1. **BetterSleeves**: The main mod which includes the **logic for rolling down sleeves and fixes to some clothing items**.
2. **BetterSleeves - CET Only**: This version has no fixes to clothing but contains the **logic to roll down sleeves**.
3. **BetterSleeves - Archive Fixes**: This is marked as "Optional" and contains **only the fixes to clothing items**. It can be used with other Sleeves mods!

### Mod Compatibility

**I recommend installing [RenderPlaneFix](https://github.com/Marco4413/CP77-RenderPlaneFix) which tries to dynamically fix rendering order issues for clothing items.**

If you're making a mod that adds a piece of clothe which has sleeves, remember to set `renderingPlaneAnimationParam` to `renderPlane`
inside your `entSkinnedMeshComponent`s within your `.ent` file. Otherwise, hands will be drawn on top of it when holding weapons/performing
certain animations.
**The setting is case-sensitive and you should set it on TPP clothing files.**

**There's also a guide available on the [Cyberpunk 2077 modding wiki](https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-creators/modding-guides/items-equipment/first-person-perspective-fixes#problem-1-your-sleeves-render-behind-your-arms).
Keep in mind that this mod works by swapping FPP models with TPP ones (which lets you switch between both sleeved and sleeveless).**

### Known Issues

- If a clothing item is both equipped in a base-game slot and Equipment-EX slot, it may not be displayed properly.

## Development

To improve your dev experience follow the README in [libs/cet](libs/cet).
