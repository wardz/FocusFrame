# FocusFrame
Provides focus targeting & frame support for **original** vanilla World of Warcraft. (1.12.1, English client)

>If you have never used focus before, it's basically a secondary target system that keeps track of a second unit other than the currently targeted unit. Once a focus is set, you can use macros to cast spells on the focus without having to lose your current target.

The focus frame works for both friendly and enemy **players**.

![alt](http://i.imgur.com/OEcWwgU.jpg)

**Update 2019**  
Development has been ceased due to the official release of WoW Classic. If possible, I'll recreate this addon for Classic, but no promises.  
**Edit:** Focus in Classic does not seem to be feasible. You can have an addon automatically create a macro for you something like:
```
/targetexact name # or /click CustomTargetFocusButton
/cast spell
/targetlasttarget
```
but the problem is that addons can only create macros outside combat, so you won't be able to switch focus reliably. There's also a delay
between /target and /cast in the macro system that sometimes makes you cast the spell on your current target instead of the new target. I recommend people to switch to mouseover macros instead, it's way more reliable. If you don't care about focus cast, there should already be several enemy frame addons out there that allow tracking health, auras, casts etc on nearby units.

## Usage & Info
- [Chat commands/macros](https://github.com/wardz/FocusFrame/wiki/Commands)
- [Options](https://github.com/wardz/FocusFrame/wiki/Options)
- [Addon limitations](https://github.com/wardz/FocusFrame/wiki/Limitations) (Important, read this!)
- [Increase combatlog distance (optional)](https://github.com/wardz/FocusFrame/wiki/Combatlog-Distance)
- [What is focus and why is it useful?](http://wow.gamepedia.com/Focus_target)

## Installation
1. Download latest [version here.](https://github.com/wardz/FocusFrame/releases)
2. Extract (unzip) the downloaded file into your `WoW/Interface/AddOns` folder.
3. Remove any suffixes from the addon's folder name. E.g: `FocusFrame-v1.0` to `FocusFrame`.

## Plugins
- [modui-FocusFrame](https://github.com/gashole/modui-FocusFrame) by [Gashole](https://github.com/gashole)
- [FocusFrame_TargetCastbar](https://github.com/wardz/FocusFrame_TargetCastbar)
