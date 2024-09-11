# CP77-BetterSleeves

![](preview.png)

## About

**This Cyberpunk 2077 mod enables you to roll up and down sleeves through CET hotkeys and menus.**

It's highly customizable thanks to blacklists and whitelists that can be managed in-game through CET.

If you've got Codeware installed, this mod also syncs inventory sleeves and allows you to manually
roll up/down sleeves in photo mode.

There are currently 2 mods which already do what this mod does:
- [Sleeves (DJ_Kovrik)](https://www.nexusmods.com/cyberpunk2077/mods/3309)
  - This mod is highly integrated with the game, it adds new UI to change the state of sleeves.
  However, it lacks hotkeys to do that without opening the inventory screen and some customizability
  that this mod provides. Though if you prefer a more integrated experience, I recommend it.
- [JB - Long Sleeves (Jelle Bakker)](https://www.nexusmods.com/cyberpunk2077/mods/987)
  - This one is very old and supposedly not maintained anymore.

### Requirements

- [CET 1.32.0+](https://github.com/yamashi/CyberEngineTweaks)
- [RenderPlaneFix](https://github.com/Marco4413/CP77-RenderPlaneFix) (recommended, dynamically fixes clothing items rendering)

### What version should I download?

There are currently 3 separate files:
1. **BetterSleeves**: The main mod which includes the **logic for rolling down sleeves and fixes to some clothing items**.
2. **BetterSleeves - CET Only**: This version has no fixes to clothing but contains the **logic to roll down sleeves**.
3. **BetterSleeves - Archive Fixes**: This is marked as "Optional" and contains **only the fixes to clothing items**. It can be used with other Sleeves mods!

### Credits

Thanks to **psiberx** for making [Codeware](https://github.com/psiberx/cp2077-codeware/)
from which I've ***"stolen"*** the code to get inventory and photo mode player puppets!

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
