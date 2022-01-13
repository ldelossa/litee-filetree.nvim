local lib_tree          = require('litee.lib.tree')
local lib_state         = require('litee.lib.state')
local marshal_func      = require('litee.filetree.marshal').marshal_func
local lib_util_win      = require('litee.lib.util.window')

local builder           = require('litee.filetree.builder')

local M = {}

-- ui_req_ctx creates a context table summarizing the
-- environment when a filetree request is being
-- made.
--
-- see return type for details.
local function ui_req_ctx()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_type   = lib_state.get_type_from_buf(tab, buf)
    local tree_handle = lib_state.get_tree_from_buf(tab, buf)
    local state       = lib_state.get_state(tab)

    local cursor = nil
    local node = nil
    if state ~= nil then
        if
            state["filetree"] ~= nil
            and state["filetree"].win ~= nil
            and vim.api.nvim_win_is_valid(state["filetree"].win)
        then
            cursor = vim.api.nvim_win_get_cursor(state["filetree"].win)
            node = lib_tree.marshal_line(cursor, state["filetree"].tree)
        end
    end

    return {
        -- the current buffer when the request is made
        buf = buf,
        -- the current win when the request is made
        win = win,
        -- the current tab when the request is made
        tab = tab,
        -- the current cursor pos when the request is made
        linenr = linenr,
        -- the type of tree if request is made in a lib_panel
        -- window.
        tree_type = tree_type,
        -- a hande to the tree if the request is made in a lib_panel
        -- window.
        tree_handle = tree_handle,
        -- the pos of the filetree cursor if a valid caltree exists.
        cursor = cursor,
        -- the current state provided by lib_state
        state = state,
        -- the current marshalled node if there's a valid filetree
        -- window present.
        node = node
    }
end

M.current_file_hl_group = nil

-- file_tracking is used to keep the filetree up to date
-- with the focused source file buffer.
M.file_tracking = function()
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end
    if
        ctx.state["filetree"] == nil or
        ctx.state["filetree"].win == nil or
        not vim.api.nvim_win_is_valid(ctx.state["filetree"].win)
        or lib_util_win.inside_component_win()
    then
        return
    end
    if M.current_file_hl_group ~= nil then
        vim.api.nvim_buf_clear_namespace(
            ctx.state["filetree"].buf,
            M.current_file_hl_group,
            0,
            -1
        )
    end

    local t = lib_tree.get_tree(ctx.state["filetree"].tree)
    if t == nil then
        return
    end
    local dpt = t.depth_table
    local target_uri = vim.fn.expand('%:p')
    builder.build_filetree_recursive(t.root, ctx.state["filetree"], dpt, target_uri)
    lib_tree.write_tree(
        ctx.state["filetree"].buf,
        ctx.state["filetree"].tree,
        marshal_func
    )

    for buf_line, node in pairs(t.buf_line_map) do
        if node.key == target_uri then
            vim.api.nvim_win_set_cursor(ctx.state["filetree"].win, {buf_line, 0})
            -- set a hl that's same color as cursor line so you can always find current
            -- file.
            M.current_file_hl_group = vim.api.nvim_buf_add_highlight(
                ctx.state["filetree"].buf,
                0,
                "CursorLine",
                buf_line-1,
                0,
                -1
            )
        end
    end
end

return M
