--- *indentscope* Work with indent scope
--- *Indentscope*
---
--- MIT License Copyright (c) 2023 HellUpLine
---
--- ==============================================================================

local M = {}
local H = {}

M.setup = function(config)
	-- Export module
	_G.Indentscope = M

	-- Setup config
	config = H.setup_config(config)

	-- Apply config
	H.apply_config(config)
end

M.config = {
  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    -- Textobjects
    object_scope = 'ii',
    object_scope_with_border = 'ai',

    -- Motions (jump to respective border line; if not present - body line)
    goto_top = '[i',
    goto_bottom = ']i',
  },

  -- Options which control scope computation
  options = {
    -- Whether to use cursor column when computing reference indent.
    -- Useful to see incremental scopes with horizontal cursor movements.
    indent_at_cursor = true,

    -- Whether to first check input line to be a border of adjacent scope.
    -- Use it if you want to place cursor on function header to get scope of
    -- its body.
    try_as_border = false,

    -- Type of scope's border: which line(s) with smaller indent to
    -- categorize as border. Can be one of: 'both', 'top', 'bottom', 'none'.
    border = "both",
  }
}

M.textobject = function(use_border)
	local scope = M.get_scope()

	-- Don't support scope that can't be shown
	if H.scope_get_draw_indent(scope) < 0 then
		return
	end

	-- Allow chaining only if using border
	local count = use_border and vim.v.count1 or 1

	-- Make sequence of incremental selections
	for _ = 1, count do
		-- Try finish cursor on border
		local start, finish = "top", "bottom"
		if use_border and scope.border.bottom == nil then
			start, finish = "bottom", "top"
		end

		H.exit_visual_mode()
		M.move_cursor(start, use_border, scope)
		vim.cmd("normal! V")
		M.move_cursor(finish, use_border, scope)

		-- Use `try_as_border = false` to enable chaining
		scope = M.get_scope(nil, nil, { try_as_border = false })

		-- Don't support scope that can't be shown
		if H.scope_get_draw_indent(scope) < 0 then
			return
		end
	end
end

M.operator = function(side, add_to_jumplist)
	local scope = M.get_scope()

	-- Don't support scope that can't be shown
	if H.scope_get_draw_indent(scope) < 0 then
		return
	end

	-- Add movement to jump list. Needs remembering `count1` before that because
	-- it seems to reset it to 1.
	local count = vim.v.count1
	if add_to_jumplist then
		vim.cmd("normal! m`")
	end

	-- Make sequence of jumps
	for _ = 1, count do
		M.move_cursor(side, true, scope)
		-- Use `try_as_border = false` to enable chaining
		scope = M.get_scope(nil, nil, { try_as_border = false })

		-- Don't support scope that can't be shown
		if H.scope_get_draw_indent(scope) < 0 then
			return
		end
	end
end

M.get_scope = function(line, col, opts)
	opts = H.get_config({ options = opts }).options

	-- Compute default `line` and\or `col`
	if not (line and col) then
		local curpos = vim.fn.getcurpos()

		line = line or curpos[2]
		line = opts.try_as_border and H.border_correctors[opts.border](line, opts) or line

		-- Use `curpos[5]` (`curswant`, see `:h getcurpos()`) to account for blank and empty lines.
		col = col or (opts.indent_at_cursor and curpos[5] or math.huge)
	end

	-- Compute "indent at column"
	local line_indent = H.get_line_indent(line, opts)
	local indent = math.min(col, line_indent)

	-- Make early return
	local body = { indent = indent }
	if indent <= 0 then
		body.top, body.bottom, body.indent = 1, vim.fn.line("$"), line_indent
	else
		local up_min_indent, down_min_indent
		body.top, up_min_indent = H.cast_ray(line, indent, "up", opts)
		body.bottom, down_min_indent = H.cast_ray(line, indent, "down", opts)
		body.indent = math.min(line_indent, up_min_indent, down_min_indent)
	end

	return {
		body = body,
		border = H.border_from_body[opts.border](body, opts),
		buf_id = vim.api.nvim_get_current_buf(),
		reference = { line = line, column = col, indent = indent },
	}
end

M.move_cursor = function(side, use_border, scope)
	scope = scope or M.get_scope()

	-- This defaults to body's side if it is not present in border
	local target_line = use_border and scope.border[side] or scope.body[side]
	target_line = math.min(math.max(target_line, 1), vim.fn.line("$"))

	vim.api.nvim_win_set_cursor(0, { target_line, 0 })
	-- Move to first non-blank character to allow chaining scopes
	vim.cmd("normal! ^")
end

H.default_config = M.config

H.setup_config = function(config)
	vim.validate({ config = { config, "table", true } })
	config = vim.tbl_deep_extend("force", H.default_config, config or {})
  vim.validate({
    mappings = { config.mappings, 'table' },
    options = { config.options, 'table' },
  })
  vim.validate({
    ['mappings.object_scope'] = { config.mappings.object_scope, 'string' },
    ['mappings.object_scope_with_border'] = { config.mappings.object_scope_with_border, 'string' },
    ['mappings.goto_top'] = { config.mappings.goto_top, 'string' },
    ['mappings.goto_bottom'] = { config.mappings.goto_bottom, 'string' },
    ['options.border'] = { config.options.border, 'string' },
    ['options.indent_at_cursor'] = { config.options.indent_at_cursor, 'boolean' },
    ['options.try_as_border'] = { config.options.try_as_border, 'boolean' },
  })
  return config
end

H.apply_config = function(config)
	M.config = config
	local mappings = config.mappings

  --stylua: ignore start
  H.map('x', mappings.goto_top, [[<Cmd>lua Indentscope.operator('top')<CR>]], { desc = 'Go to indent scope top' })
  H.map('x', mappings.goto_bottom, [[<Cmd>lua Indentscope.operator('bottom')<CR>]], { desc = 'Go to indent scope bottom' })
  H.map('x', mappings.object_scope, '<Cmd>lua Indentscope.textobject(false)<CR>', { desc = 'Object scope' })
  H.map('x', mappings.object_scope_with_border, '<Cmd>lua Indentscope.textobject(true)<CR>', { desc = 'Object scope with border' })

  H.map('n', mappings.goto_top, [[<Cmd>lua Indentscope.operator('top', true)<CR>]], { desc = 'Go to indent scope top' })
  H.map('n', mappings.goto_bottom, [[<Cmd>lua Indentscope.operator('bottom', true)<CR>]], { desc = 'Go to indent scope bottom' })

  -- Use `<Cmd>...<CR>` to have proper dot-repeat
  -- See https://github.com/neovim/neovim/issues/23406
  -- TODO: use local functions if/when that issue is resolved
  H.map('o', mappings.object_scope, '<Cmd>lua Indentscope.textobject(false)<CR>', { desc = 'Object scope' })
  H.map('o', mappings.object_scope_with_border, '<Cmd>lua Indentscope.textobject(true)<CR>', { desc = 'Object scope with border' })

  H.map('o', mappings.goto_top, [[<Cmd>lua Indentscope.operator('top')<CR>]], { desc = 'Go to indent scope top' })
  H.map('o', mappings.goto_bottom, [[<Cmd>lua Indentscope.operator('bottom')<CR>]], { desc = 'Go to indent scope bottom' })
	--stylua: ignore start
end

H.get_config = function(config)
	return vim.tbl_deep_extend("force", M.config, vim.b.miniindentscope_config or {}, config or {})
end

H.indent_funs = {
	["min"] = function(top_indent, bottom_indent)
		return math.min(top_indent, bottom_indent)
	end,
	["max"] = function(top_indent, bottom_indent)
		return math.max(top_indent, bottom_indent)
	end,
	["top"] = function(top_indent, bottom_indent)
		return top_indent
	end,
	["bottom"] = function(top_indent, bottom_indent)
		return bottom_indent
	end,
}

H.blank_indent_funs = {
	["both"] = H.indent_funs.max,
	["top"] = H.indent_funs.bottom,
	["bottom"] = H.indent_funs.top,
	["none"] = H.indent_funs.min,
}

H.border_from_body = {
	["both"] = function(body, opts)
		return {
			top = body.top - 1,
			bottom = body.bottom + 1,
			indent = math.max(H.get_line_indent(body.top - 1, opts), H.get_line_indent(body.bottom + 1, opts)),
		}
	end,
	["top"] = function(body, opts)
		return { top = body.top - 1, indent = H.get_line_indent(body.top - 1, opts) }
	end,
	["bottom"] = function(body, opts)
		return { bottom = body.bottom + 1, indent = H.get_line_indent(body.bottom + 1, opts) }
	end,
	["none"] = function(body, opts)
		return {}
	end,
}

H.border_correctors = {
	["none"] = function(line, opts)
		return line
	end,
	["top"] = function(line, opts)
		local cur_indent, next_indent = H.get_line_indent(line, opts), H.get_line_indent(line + 1, opts)
		return (cur_indent < next_indent) and (line + 1) or line
	end,
	["bottom"] = function(line, opts)
		local prev_indent, cur_indent = H.get_line_indent(line - 1, opts), H.get_line_indent(line, opts)
		return (cur_indent < prev_indent) and (line - 1) or line
	end,
	["both"] = function(line, opts)
		local prev_indent, cur_indent, next_indent =
			H.get_line_indent(line - 1, opts), H.get_line_indent(line, opts), H.get_line_indent(line + 1, opts)

		if prev_indent <= cur_indent and next_indent <= cur_indent then
			return line
		end

		-- If prev and next indents are equal and bigger than current, prefer next
		if prev_indent <= next_indent then
			return line + 1
		end

		return line - 1
	end,
}

H.get_line_indent = function(line, opts)
	local prev_nonblank = vim.fn.prevnonblank(line)
	local res = vim.fn.indent(prev_nonblank)

	-- Compute indent of blank line depending on `options.border` values
	if line ~= prev_nonblank then
		local next_indent = vim.fn.indent(vim.fn.nextnonblank(line))
		local blank_rule = H.blank_indent_funs[opts.border]
		res = blank_rule(res, next_indent)
	end

	return res
end

H.cast_ray = function(line, indent, direction, opts)
	local final_line, increment = 1, -1
	if direction == "down" then
		final_line, increment = vim.fn.line("$"), 1
	end

	local min_indent = math.huge
	for l = line, final_line, increment do
		local new_indent = H.get_line_indent(l + increment, opts)
		if new_indent < indent then
			return l, min_indent
		end
		if new_indent < min_indent then
			min_indent = new_indent
		end
	end

	return final_line, min_indent
end

H.scope_get_draw_indent = function(scope)
	return scope.border.indent or (scope.body.indent - 1)
end

H.scope_is_equal = function(scope_1, scope_2)
	if type(scope_1) ~= "table" or type(scope_2) ~= "table" then
		return false
	end

	return scope_1.buf_id == scope_2.buf_id
		and H.scope_get_draw_indent(scope_1) == H.scope_get_draw_indent(scope_2)
		and scope_1.body.top == scope_2.body.top
		and scope_1.body.bottom == scope_2.body.bottom
end

H.map = function(mode, lhs, rhs, opts)
	if lhs == "" then
		return
	end
	opts = vim.tbl_deep_extend("force", { silent = true }, opts or {})
	vim.keymap.set(mode, lhs, rhs, opts)
end

H.exit_visual_mode = function()
	local ctrl_v = vim.api.nvim_replace_termcodes("<C-v>", true, true, true)
	local cur_mode = vim.fn.mode()
	if cur_mode == "v" or cur_mode == "V" or cur_mode == ctrl_v then
		vim.cmd("normal! " .. cur_mode)
	end
end

return M
