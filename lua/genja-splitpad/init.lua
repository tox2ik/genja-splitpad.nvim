-- Padding column next to vertical split separators in unfocused windows.
-- Drawn with ephemeral extmarks from a decoration provider, so it is per window, not per buffer.
local M = {}

local SRC = 'genja-splitpad/init.lua: '
local ns = vim.api.nvim_create_namespace('genja-splitpad')
local group = vim.api.nvim_create_augroup('genja-splitpad', { clear = true })
local EOB_ENTRY = 'EndOfBuffer:SplitPadEob'

---@class genja-splitpad.Opts
---@field enabled? boolean draw from startup (default true)
---@field min_width? integer narrower windows get no padding (default 10)
---@field exclude_ft? string[] filetypes without padding
---@field exclude_bt? string[] buftypes without padding
---@field eob_darken? number background factor for the area below the end of the buffer (default 0.85)

---@type genja-splitpad.Opts
local defaults = {
	enabled = true,
	min_width = 10,
	exclude_ft = { 'oil', 'help' },
	exclude_bt = { 'prompt', 'quickfix', 'help' }, -- 'terminal', 
	eob_darken = 0.85,
}

---@type genja-splitpad.Opts
local config = defaults
local enabled = false

-- The window the user is in, set on WinEnter. nvim_get_current_win() can't be trusted
-- during a redraw: other plugins may temporarily switch to the window being drawn.
---@type integer
local focused = vim.api.nvim_get_current_win()

-- Text columns to cover per window for the current redraw: filled in on_win, read in on_line.
---@type table<integer, integer[]>
local cols_by_win = {}

---@param win integer
---@return boolean
local function should_pad(win)
	if not vim.api.nvim_win_is_valid(win) then
		return false
	end
	if vim.api.nvim_win_get_config(win).relative ~= '' then
		return false
	end
	if vim.api.nvim_win_get_width(win) < config.min_width then
		return false
	end
	local buf = vim.api.nvim_win_get_buf(win)
	if vim.tbl_contains(config.exclude_bt, vim.bo[buf].buftype) then
		return false
	end
	if vim.tbl_contains(config.exclude_ft, vim.bo[buf].filetype) then
		return false
	end
	return true
end

-- A separator sits on the left when anything is left of the window,
-- and on the right when the window doesn't reach the last screen column.
-- Columns count from the first text column (after number/sign columns), as virt_text_win_col does.
---@param win integer
---@return integer[]
local function pad_cols(win)
	local cols = {}
	local col = vim.api.nvim_win_get_position(win)[2]
	local width = vim.api.nvim_win_get_width(win)
	local text_width = width - vim.fn.getwininfo(win)[1].textoff
	if text_width < 2 then
		return cols
	end
	if col > 0 then
		table.insert(cols, 0)
	end
	if col + width < vim.o.columns then
		table.insert(cols, text_width - 1)
	end
	return cols
end

---@param win integer
---@return boolean
local function is_padded(win)
	if not enabled or win == focused then
		return false
	end
	if not should_pad(win) then
		return false
	end
	return #pad_cols(win) > 0
end

-- Decoration provider -------------------------------------------------------

local function on_start()
	cols_by_win = {}
	return enabled
end

local function on_win(_, win)
	if not is_padded(win) then
		return false
	end
	cols_by_win[win] = pad_cols(win)
	return true
end

local function on_line(_, win, buf, row)
	local cols = cols_by_win[win]
	if cols == nil then
		return
	end
	for _, col in ipairs(cols) do
		vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
			virt_text = { { ' ', 'SplitPadNC' } },
			virt_text_win_col = col,
			ephemeral = true,
		})
	end
end

-- End-of-buffer dimming -----------------------------------------------------

-- Adds or removes our entry in the window's local 'winhighlight'; leaves other entries alone.
---@param win integer
---@param on boolean
local function set_eob(win, on)
	local current = vim.api.nvim_get_option_value('winhighlight', { win = win, scope = 'local' })
	local entries = vim.split(current, ',', { trimempty = true })
	local has = vim.tbl_contains(entries, EOB_ENTRY)

	if on and not has then
		-- Someone else already maps EndOfBuffer here: don't fight it.
		for _, entry in ipairs(entries) do
			if vim.startswith(entry, 'EndOfBuffer:') then
				return
			end
		end
		table.insert(entries, EOB_ENTRY)
	elseif not on and has then
		entries = vim.tbl_filter(function(entry) return entry ~= EOB_ENTRY end, entries)
	else
		return
	end

	vim.api.nvim_set_option_value('winhighlight', table.concat(entries, ','), { win = win, scope = 'local' })
end

-- Highlights ----------------------------------------------------------------

---@param name string
---@return integer|nil
local function get_bg(name)
	return vim.api.nvim_get_hl(0, { name = name, link = false }).bg
end

---@param rgb integer
---@param factor number
---@return integer
local function darken(rgb, factor)
	local r = math.floor(math.floor(rgb / 65536) % 256 * factor)
	local g = math.floor(math.floor(rgb / 256) % 256 * factor)
	local b = math.floor(rgb % 256 * factor)
	return r * 65536 + g * 256 + b
end

local function set_highlights()
	local bg = get_bg('NormalNC')
	if bg == nil then
		bg = get_bg('Normal')
	end
	vim.api.nvim_set_hl(0, 'SplitPadNC', { bg = bg })

	-- Transparent background: nothing to darken, so the ~ area keeps EndOfBuffer's look.
	local eob = vim.api.nvim_get_hl(0, { name = 'EndOfBuffer', link = false })
	local eob_bg = eob.bg
	if bg ~= nil then
		eob_bg = darken(bg, config.eob_darken)
	end
	vim.api.nvim_set_hl(0, 'SplitPadEob', { fg = eob.fg, bg = eob_bg })
end

-- Refresh -------------------------------------------------------------------

-- Updates the ~ dimming and marks windows for redraw: the provider only runs on redraw,
-- and a focus change alone doesn't redraw the text of the window that was left.
local function refresh()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_get_config(win).relative == '' then
			set_eob(win, is_padded(win))
			vim.api.nvim__redraw({ win = win, valid = false })
		end
	end
end

-- Coalesces bursts of events (:split fires WinNew, WinEnter, WinResized) into one refresh.
local pending = false
local function schedule_refresh()
	if pending then
		return
	end
	pending = true
	vim.schedule(function()
		pending = false
		refresh()
	end)
end

local function clear_all()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_config(win).relative == '' then
			set_eob(win, false)
		end
	end
	vim.api.nvim__redraw({ valid = false })
end

-- Public --------------------------------------------------------------------

function M.toggle()
	enabled = not enabled
	local state = 'off'
	if enabled then
		state = 'on'
		refresh()
	else
		clear_all()
	end
	vim.notify(SRC .. 'split padding ' .. state)
end

---@param opts? genja-splitpad.Opts
function M.setup(opts)
	config = vim.tbl_extend('force', defaults, opts or {})
	enabled = config.enabled
	focused = vim.api.nvim_get_current_win()

	set_highlights()

	vim.api.nvim_set_decoration_provider(ns, {
		on_start = on_start,
		on_win = on_win,
		on_line = on_line,
	})

	vim.api.nvim_clear_autocmds({ group = group })
	vim.api.nvim_create_autocmd('ColorScheme', {
		group = group,
		callback = set_highlights,
	})
	-- Redraw the window left and the window entered right away; the scheduled refresh can come too late.
	vim.api.nvim_create_autocmd('WinEnter', {
		group = group,
		callback = function()
			local prev = focused
			focused = vim.api.nvim_get_current_win()
			if not enabled then
				return
			end
			if vim.api.nvim_win_is_valid(prev) then
				vim.api.nvim__redraw({ win = prev, valid = false })
			end
			vim.api.nvim__redraw({ win = focused, valid = false })
			schedule_refresh()
		end,
	})
	vim.api.nvim_create_autocmd({ 'WinResized', 'VimResized', 'TabEnter', 'BufWinEnter', 'FileType' }, {
		group = group,
		callback = function()
			if enabled then
				schedule_refresh()
			end
		end,
	})

	vim.api.nvim_create_user_command('SplitPadToggle', M.toggle, { desc = 'Toggle: split padding' })

	if enabled then
		refresh()
	end
end

return M
