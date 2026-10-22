# genja-splitpad.nvim

Draw a blank padding column on the inside of unfocused split windows, next to
the vertical separator. The column disappears when the window gains focus.

## How it looks

- Only the separator side is padded: the left edge when a window is to the
  left, the right edge when one is to the right. A middle window gets both.
- The column is a blank cell in the window's background (`NormalNC`, else
  `Normal`), so it reads as padding rather than a bar.
- It is drawn as virtual text on top of the text: the first or last visible
  character is hidden while the window is unfocused.
- The left-edge column sits after the number and sign columns:
  `virt_text_win_col` counts from the first text column.
- No column on wrapped continuation rows or on `~` rows below the end of the
  buffer. Instead, the `~` area of a padded window gets a darker background.
- A buffer shown in a focused and an unfocused window is padded only in the
  unfocused one.

## Install and setup

```lua
{
	'USERNAME/genja-splitpad.nvim',
	event = 'VeryLazy',
	keys = {
		{ '<leader>tp', function() require('genja-splitpad').toggle() end, desc = 'Toggle: split padding' },
	},
	opts = {
		enabled = true,     -- draw from startup
		min_width = 10,     -- narrower windows get no padding
		exclude_ft = { 'oil', 'help' },
		exclude_bt = { 'terminal', 'prompt', 'quickfix', 'help' },
		eob_darken = 0.85,  -- background factor for the ~ area
	},
}
```

Floating windows are never padded.

## Commands and API

- `:SplitPadToggle`, `toggle()`: turn padding on or off.
- `setup(opts)`: see the options above.

## Highlights

- `SplitPadNC`: the padding column. Background from `NormalNC` or `Normal`.
- `SplitPadEob`: the `~` area of padded windows, via window-local
  `winhighlight` `EndOfBuffer:SplitPadEob`. A window that already maps
  `EndOfBuffer` is left alone.

Both are recomputed on `ColorScheme`.

## Requirements

Neovim 0.11+ (uses `nvim_set_decoration_provider` and `nvim__redraw`).

## License

MIT
