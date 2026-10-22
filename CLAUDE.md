# genja-splitpad.nvim

Draws a padding column on the inside of unfocused split windows, next to the
vertical separator. Loaded from disk by the config's
`../../lua/lazyp/new/genja-splitpad.lua` (`dir =` spec, `VeryLazy`), keys in
`../../lua/genja/map-plugin/genja-splitpad.lua`.

How this file is kept: one heading per feature, one bullet per decision.
Unmarked bullets were stated by jaro. `(inferred)` marks Claude's reading of the
code or history: confirm or delete. `Hint:` is a working note for Claude.

## Layout

- `lua/genja-splitpad/init.lua`: `setup(opts)`, `toggle()`, `:SplitPadToggle`.
- Mappings stay in the config. The plugin must not require `genja.*`. (inferred: same rule as genja-oily)

## Drawing

- Virt text ("ghost text"), not `statuscolumn`: don't abuse the statusline/statuscolumn.
- Ephemeral extmarks from a decoration provider, so a buffer shown in a focused and an unfocused window is padded only in the unfocused one. (inferred: implementation choice)
- Pad only the separator side: left edge if a window is to the left, right edge if one is to the right; a middle window gets both.
- Overlay anyway: the column covers the first or last visible text character while unfocused.
- The column is a blank cell with the window background: `SplitPadNC` takes the bg of `NormalNC`, falling back to `Normal`; recomputed on `ColorScheme`.
- `virt_text_win_col` counts from the first text column, so the left-edge column sits after the number/sign columns, not against the separator. (inferred: API limit)
- Accepted gaps: no column on wrap continuation rows or on `~` rows below the end of the buffer.
- The `~` area of unfocused padded windows is dimmed instead: window-local `winhighlight` `EndOfBuffer:SplitPadEob`, bg darkened by `eob_darken`. An existing `EndOfBuffer:` mapping in that window is left alone. (inferred: details)
- Hint: the provider only runs on redraw; `refresh()` calls `nvim__redraw` on focus/layout events.

## Floating column (later)

- A 1-column non-focusable float per unfocused window is the planned alternative, to try later; it would cover `~` and wrapped rows.
- Hint: `focusable = false` keeps it out of `<C-w>w/W/p`; `<C-w>hjkl` never enter floats; `mouse = false` lets clicks through. Check `:windo` manually.

## Toggle and exclusions

- On by default; `:SplitPadToggle` and `<leader>tp`.
- No padding in: floats, buftypes `terminal`/`prompt`/`quickfix`, filetypes `oil`/`help`, windows narrower than 10 columns.
