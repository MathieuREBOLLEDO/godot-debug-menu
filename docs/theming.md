# Theming

The debug menu looks like the Godot editor (default Godot 4 theme: blue-gray
background, blue accent, editor font), so it blends with your tools. Every
color, font and size is a *design token* with a built-in default: nothing to
install.

## Per player: in-game settings

**⚙ Settings > Appearance** changes the accent, background, size and font.
These choices are saved per machine (`user://`) and override the tokens.

## Per project: `res://design_tokens.cfg`

To change the defaults for a whole project, create `res://design_tokens.cfg`
(a Godot `ConfigFile`). Only write the values you change; the others keep
their default.

```ini
[colors]
accent="ffb020"

[sizes]
text=16
```

| Section | Key | Default | Role |
|---|---|---|---|
| profile | follow_editor | `true` | in the editor, use the colors of the open editor theme |
| colors | ink | `1d2229` | deepest background (fields, lists) |
| colors | ink_panel | `252b34` | bar, windows, headers |
| colors | ink_raised | `363d4a` | buttons, cards, hover |
| colors | ink_line | `414957` | 1 px separators |
| colors | sand | `e0e0e0` | text |
| colors | sand_dim | `8b929c` | secondary text (captions, help) |
| colors | accent | `70bbfa` | the one accent: selection, focus, main action |
| colors | good | `45d17c` | valid, open, loaded |
| colors | bad | `ff786b` | problem, error, recording |
| colors | info | `a5b6cc` | information, empty |
| fonts | ui | `@engine` | interface font (`@engine`: the editor font, Godot's default font in game; otherwise system font names) |
| fonts | mono | `JetBrains Mono, Cascadia Mono, Consolas, Menlo` | values, coordinates, fields |
| fonts | condensed_width / condensed_weight | `100` / `600` | narrow bold variant (titles, section headers) |
| sizes | text / title / small / radius | `14` / `16` / `12` / `3` | text sizes and corner radius |

Colors are hexadecimal strings (`"ffb020"`). Font lists are tried in order.

## Your own windows

Windows built on `res://addons/debug_menu/ui/debug_window.gd` (see the
[API reference](api.md#custom-windows)) get the theme automatically. Keep
the same spirit: one accent for what the user manipulates, meaning colors
(good, bad, info) only for meaning, explanations in `add_hint()` bubbles
rather than long text.
