local lib_state         = require('litee.lib.state')
local lib_panel         = require('litee.lib.panel')
local lib_tree          = require('litee.lib.tree')
local lib_tree_node     = require('litee.lib.tree.node')

local config            = require('litee.filetree.config').config
local filetree_au       = require('litee.filetree.autocmds')
local filetree_marshal  = require('litee.filetree.marshal')
local builder            = require('litee.filetree.builder')


local M = {}

-- filetree_handler handles the initial request for creating a filetree
-- for a particular tab.
function M.filetree_handler(root_dir)
    local cur_win = vim.api.nvim_get_current_win()
    local cur_tabpage = vim.api.nvim_win_get_tabpage(cur_win)
    local state_was_nil = false

    local state = lib_state.get_component_state(cur_tabpage, "filetree")
    if state == nil then
        state_was_nil = true
        state = {}
        -- create new tree, throwing old one out if exists
        if state.tree ~= nil then
            lib_tree.remove_tree(state.tree)
        end
        state.tree = lib_tree.new_tree("filetree")
        -- store the window invoking the filetree, jumps will
        -- occur here.
        state.invoking_win = vim.api.nvim_get_current_win()
        -- store the tab which invoked the filetree.
        state.tab = cur_tabpage
    end


    local cwd = vim.fn.getcwd()
    if root_dir ~= nil or root_dir == "" then
        cwd = root_dir
    end

    -- create the root of our filetree
    local root = lib_tree_node.new_node(
         cwd,
         cwd,
         0
    )
    root.filetree_item = { uri = cwd, is_dir = true}
    local range = {}
    range["start"] = { line = 0, character = 0}
    range["end"] = { line = 0, character = 0}
    root.location = {
        uri = "file://" .. root.filetree_item.uri,
        range = range
    }

    builder.build_filetree_recursive(root, state, nil, "")

    local global_state = lib_state.put_component_state(cur_tabpage, "filetree", state)

    -- state was not nil, can we reuse the existing win
    -- and buffer?
    if
        not state_was_nil
        and state.win ~= nil
        and vim.api.nvim_win_is_valid(state.win)
        and state.buf ~= nil
        and vim.api.nvim_buf_is_valid(state.buf)
    then
        lib_tree.write_tree(
            state.buf,
            state.tree,
            filetree_marshal.marshal_func
        )
    else
        -- we have no state, so open up the panel or popout to create
        -- a window and buffer.
        if config.on_open == "popout" then
            lib_panel.popout_to("filetree", global_state, filetree_au.file_tracking())
        else
            lib_panel.toggle_panel(global_state, true, false)
            -- run file_tracking to initially update filetree view.
            filetree_au.file_tracking()
        end
    end

end

return M
