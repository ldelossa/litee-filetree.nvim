local lib_state         = require('litee.lib.state')
local lib_tree          = require('litee.lib.tree')
local lib_panel         = require('litee.lib.panel')
local lib_util          = require('litee.lib.util')
local lib_details       = require('litee.lib.details')
local lib_notify        = require('litee.lib.notify')
local lib_jumps         = require('litee.lib.jumps')
local lib_navi          = require('litee.lib.navi')
local lib_util_win      = require('litee.lib.util.window')
local lib_path          = require('litee.lib.util.path')

local filetree_buf      = require('litee.filetree.buffer')
local filetree_au       = require('litee.filetree.autocmds')
local filetree_help_buf = require('litee.filetree.help_buffer')
local marshal_func      = require('litee.filetree.marshal').marshal_func
local details_func      = require('litee.filetree.details').details_func
local config            = require('litee.filetree.config').config
local builder           = require('litee.filetree.builder')
local handlers          = require('litee.filetree.handlers')

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
        if state["filetree"] ~= nil and state["filetree"].win ~= nil and
            vim.api.nvim_win_is_valid(state["filetree"].win) then
            cursor = vim.api.nvim_win_get_cursor(state["filetree"].win)
        end
        if cursor ~= nil then
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

function M.open_to()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state["filetree"] == nil
    then
        return
    end
    if not lib_util_win.is_component_win(ctx.tab, vim.api.nvim_get_current_win()) then
        ctx.state["filetree"].invoking_win = vim.api.nvim_get_current_win()
    end
    lib_panel.open_to("filetree", ctx.state)
end

function M.popout_to()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state["filetree"] == nil
    then
        vim.cmd(":LTOpenFiletree")
        ctx = ui_req_ctx()
        -- little hacky, but we need to close it again or else
        -- popout_to will think the user had it opened and incorrectly
        -- open the panel again.
        lib_panel.toggle_panel(ctx.state, false, false, true)
    end
    if not lib_util_win.is_component_win(ctx.tab, vim.api.nvim_get_current_win()) then
        ctx.state["filetree"].invoking_win = vim.api.nvim_get_current_win()
    end
    lib_panel.popout_to("filetree", ctx.state, filetree_au.file_tracking)
end

-- close_filetree will close the filetree ui in the current tab
-- and remove the corresponding tree from memory.
--
-- use hide_filetree if you simply want to hide a filetree
-- component temporarily (not removing the tree from memory)
function M.close_filetree()
    local ctx = ui_req_ctx()
    if ctx.state["filetree"].win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state["filetree"].win) then
            vim.api.nvim_win_close(ctx.state["filetree"].win, true)
        end
    end
    if ctx.state["filetree"].buf ~= nil then
        if vim.api.nvim_buf_is_valid(ctx.state["filetree"].buf) then
            vim.api.nvim_buf_delete(ctx.state["filetree"].buf, {force = true})
        end
    end
    if ctx.state["filetree"].tree ~= nil then
        lib_tree.remove_tree(ctx.state["filetree"].tree)
    end
    lib_state.put_component_state(ctx.tab, "filetree", nil)
end

-- hide_filetree will remove the filetree component from
-- the a panel temporarily.
--
-- on panel toggle the filetree will be restored.
function M.hide_filetree()
    local ctx = ui_req_ctx()
    if ctx.tree_type ~= "filetree" then
        return
    end
    if ctx.state["filetree"].win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state["filetree"].win) then
            vim.api.nvim_win_close(ctx.state["filetree"].win, true)
        end
    end
    if vim.api.nvim_win_is_valid(ctx.state["filetree"].invoking_win) then
        vim.api.nvim_set_current_win(ctx.state["filetree"].invoking_win)
    end
end

function M.collapse_filetree(extrn_ctx)
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must open the file explorer first", 7500, "error")
        return
    end
    -- allow passing an external ctx to support
    -- "config.expand_dir_on_jump"
    if extrn_ctx ~= nil then
        ctx = extrn_ctx
    end
    ctx.node.expanded = false
    lib_tree.remove_subtree(ctx.state["filetree"].tree, ctx.node, true)
    lib_tree.write_tree(
        ctx.state["filetree"].buf,
        ctx.state["filetree"].tree,
        marshal_func
    )
    vim.api.nvim_win_set_cursor(ctx.state["filetree"].win, ctx.cursor)
end

M.collapse_all_filetree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must open the file explorer first", 7500, "error")
        return
    end
    local t = lib_tree.get_tree(ctx.state["filetree"].tree)
    lib_tree.collapse_subtree(t.root)
    lib_tree.write_tree(
        ctx.state["filetree"].buf,
        ctx.state["filetree"].tree,
        marshal_func
    )
end

M.expand_filetree = function(extrn_ctx)
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must open the file explorer first", 7500, "error")
        return
    end
    -- allow passing an external ctx to support
    -- "config.expand_dir_on_jump"
    if extrn_ctx ~= nil then
        ctx = extrn_ctx
    end
    if not ctx.node.expanded then
        ctx.node.expanded = true
    end
    builder.expand(ctx.node, ctx.state["filetree"])
    lib_tree.write_tree(
        ctx.state["filetree"].buf,
        ctx.state["filetree"].tree,
        marshal_func
    )
    vim.api.nvim_win_set_cursor(ctx.state["filetree"].win, ctx.cursor)
end

M.jump_filetree = function(split)
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 7500, "error")
        return
    end

    -- this options hijacks a jump command if the
    -- node is a dir and expands it instead.
    if config.expand_dir_on_jump then
        if ctx.node.filetree_item.is_dir and not ctx.node.expanded then
            M.expand_filetree(ctx)
            return
        elseif ctx.node.filetree_item.is_dir and ctx.node.expanded then
            M.collapse_filetree(ctx)
            return
        end
    end


    local location = ctx.node.location
    if location == nil or location.range.start.line == -1 then
        return
    end

    if split == "tab" then
        lib_jumps.jump_tab(location, ctx.node)
        return
    end

    if split == "split" or split == "vsplit" then
        lib_jumps.jump_split(split, location, ctx.node)
        return
    end

    if config.jump_mode == "neighbor" then
        lib_jumps.jump_neighbor(location, ctx.node)
        return
    end

    if config.jump_mode == "invoking" then
            local invoking_win = ctx.state["filetree"].invoking_win
            ctx.state["filetree"].invoking_win = lib_jumps.jump_invoking(location, invoking_win, ctx.node)
        return
    end
end

-- resolves the parent directory of a given url
function M.resolve_parent_directory(uri)
    local final_sep = vim.fn.strridx(uri, "/")
    local dir = vim.fn.strpart(uri, 0, final_sep+1)
    return dir
end

-- provides the filename with no path details for
-- the provided uri.
function M.resolve_file_name(uri)
    local final_sep = vim.fn.strridx(uri, "/")
    local dir = vim.fn.strpart(uri, final_sep+1, vim.fn.strlen(uri))
    return dir
end

-- var for holding any currently selected
-- node.
local selected_node = nil

-- select stores the provided node for a following
-- action and updates cursorline hi for the filetree_win
-- to indicate the node is selected.
function M.select(node, component_state)
    M.deselect(component_state)
    selected_node = node
    vim.api.nvim_win_set_option(component_state.win, 'winhl', "CursorLine:" .. "LTSelectFiletree")
    local type = (function() if node.filetree_item.is_dir then return "[dir]" else return "[file]" end end)()
    local details = type .. " " .. lib_util.relative_path_from_uri(node.key)
    lib_notify.notify_popup(details .. " selected", "warning")
end

-- select stores the provided node for a following
-- action and updates cursorline hi for the filetree_win
-- to indicate the node is selected.
function M.deselect(component_state)
    selected_node = nil
    vim.api.nvim_win_set_option(component_state.win, 'winhl', "CursorLine:CursorLine")
    lib_notify.close_notify_popup()
end

-- touch will create a new file on the file system.
-- if `node` is a directory the file will be created
-- as a child of said directory.
--
-- if `node` is a regular file the file will be created
-- at the same level as said regular file.
function M.touch(node, component_state, cb)
    if node.filetree_item == nil then
        return
    end
    local touch = function(input)
        if input == nil then
            return
        end
        local touch_path = ""
        local parent_dir = ""
        if node.filetree_item.is_dir then
            parent_dir = node.filetree_item.uri .. '/'
            touch_path = parent_dir .. input
            node.expanded = true
        else
            parent_dir = M.resolve_parent_directory(node.filetree_item.uri)
            touch_path = parent_dir .. input
        end

        local perms = vim.fn.getfperm(touch_path)
        if perms ~= "" then
            vim.ui.input(
            {
                prompt = string.format("\r%s exists, rename or overwrite (empty). Provide no input to cancel operation: ", touch_path),
                default = input,
            },
            function(new_basename)
                if new_basename == nil or new_basename == "" then
                    return
                end
                if node.filetree_item.is_dir then
                    parent_dir = node.filetree_item.uri .. '/'
                    touch_path = parent_dir .. new_basename
                    node.expanded = true
                else
                    parent_dir = M.resolve_parent_directory(node.filetree_item.uri)
                    touch_path = parent_dir .. new_basename
                end
                if vim.fn.writefile({},touch_path) == -1 then
                    return
                end
            end)
        else
            if vim.fn.writefile({},touch_path) == -1 then
                return
            end
        end

        local t = lib_tree.get_tree(component_state.tree)
        local dpt = t.depth_table
        builder.build_filetree_recursive(t.root, component_state, dpt, parent_dir)
        cb()
    end
    vim.ui.input({prompt = "New file name: "},
        touch
    )
end

-- mkdir will create a directory.
--
-- if `node` is a directory a subdirectory
-- will be created under the former directory.
--
-- if `node` is a regular file a directory
-- will be create at the same level as
-- said regular file.
function M.mkdir(node, component_state, cb)
    if node.filetree_item == nil then
        return
    end
    local mkdir = function(input)
        if input == nil then
            return
        end
        local mkdir_path = ""
        local parent_dir = ""
        if node.filetree_item.is_dir then
            parent_dir = node.filetree_item.uri .. '/'
            mkdir_path = parent_dir .. input
            node.expanded = true
        else
            parent_dir = M.resolve_parent_directory(node.filetree_item.uri)
            mkdir_path = parent_dir .. input
        end

        local perms = vim.fn.getfperm(mkdir_path)
        if perms ~= "" then
            vim.ui.input(
            {
                prompt = string.format("\r%s exists, rename or operation will have no effect: ", mkdir_path),
                default = input,
            },
            function(new_basename)
                if new_basename == nil or new_basename == "" then
                    return
                end
                if node.filetree_item.is_dir then
                    parent_dir = node.filetree_item.uri .. '/'
                    mkdir_path = parent_dir .. new_basename
                    node.expanded = true
                else
                    parent_dir = M.resolve_parent_directory(node.filetree_item.uri)
                    mkdir_path = parent_dir .. new_basename
                end
            end)
        else
            if vim.fn.mkdir(mkdir_path) == -1 then
                return
            end
        end

        local t = lib_tree.get_tree(component_state.tree)
        local dpt = t.depth_table
        builder.build_filetree_recursive(t.root, component_state, dpt, parent_dir)
        cb()
    end
    vim.ui.input({prompt = "New directory name: "},
        mkdir
    )
end

-- rm will remove the file associated with the node
-- from the file system.
function M.rm(node, component_state, cb)
    if node.filetree_item == nil then
        return
    end
    if node.depth == 0 then
        lib_notify.notify_popup_with_timeout("Cannot remove your project's root directory.", 7500, "error")
        return
    end
    vim.ui.input({prompt = string.format("Delete %s? (y/n) ", node.filetree_item.uri)},function(input)
        if input == nil then
            return
        end
        if input == "y" then
            if vim.fn.delete(node.filetree_item.uri, 'rf') == -1 then
                lib_notify.notify_popup_with_timeout(string.format("Deletion failed for %s", node.filetree_item.uri, input), 7500, "error")
                return
            end
            local t = lib_tree.get_tree(component_state.tree)
            local dpt = t.depth_table
            builder.build_filetree_recursive(t.root, component_state, dpt)
            cb()
            return
        end
        if input ~= "n" then
            lib_notify.notify_popup_with_timeout(string.format("Did not understand input: %s, delete aborted.", input), 7500, "error")
        end
        cb()
    end)
end

local function rename_file_helper(old_path, new_path)
    -- holds info about buffers and their windows
    -- which have `old_dir` in their paths.
    local buffer_to_rename = nil
    local wins = {}
    -- check if we have a buffer open for old_path
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local buffer_name = vim.api.nvim_buf_get_name(buf)
        if buffer_name == old_path then
            buffer_to_rename = buf
        end
    end
    -- collect any windows which have this buf open
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buffer_to_rename then
            table.insert(wins, win)
        end
    end
    -- callback to be ran after rename
    return function()
        -- swap wins over to new_path
        for _, win in ipairs(wins) do
            vim.api.nvim_set_current_win(win)
            vim.cmd('silent edit ' .. new_path)
        end
        -- delete old buffer
        if buffer_to_rename ~= nil then
            vim.api.nvim_buf_delete(buffer_to_rename, {force=true})
        end
    end
end

-- rename_dir_help searches for any buffers and windows
-- which have the old dir name opened, and returns a
-- callback to be called to swap them over to the new
-- paths.
local function rename_dir_helper(old_dir, new_dir)
    -- holds info about buffers and their windows
    -- which have `old_dir` in their paths.
    local buffers_to_rename = {}
    -- collect all buffer ids which have a prefix match
    -- of old_dir
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local buffer_name = vim.api.nvim_buf_get_name(buf)
        if lib_path.path_prefix_match(old_dir, buffer_name) then
            table.insert(buffers_to_rename, {
                buf = buf, path = buffer_name, wins = {}
            })
        end
    end
    -- collect all the windows for each buffer with our
    -- old_dir prefix
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local win_buf = vim.api.nvim_win_get_buf(win)
        for _, buf_info in ipairs(buffers_to_rename) do
            if win_buf == buf_info.buf then
                table.insert(buf_info.wins, win)
            end
        end
    end
    -- calback to be ran after rename occurs
    return function()
        -- create a temp empty buffer, all windows will be swapped
        -- here first
        local tmp_buf = vim.api.nvim_create_buf(true, true)

        -- we need to set all windows which are a child of
        -- old_dir to a tmp buf and then delete the
        -- or else we get errors when
        -- swapping them
        for _, buf_info in ipairs(buffers_to_rename) do
            local new_path = lib_path.swap_path_prefix(
                buf_info.path,
                old_dir,
                new_dir
            )
            for _, win in ipairs(buf_info.wins) do
                -- write the buffer out before swapping to
                -- and deleting it to be safe.
                vim.api.nvim_set_current_win(win)
                vim.cmd('silent! w! ' .. new_path)
                vim.api.nvim_win_set_buf(win, tmp_buf)
            end
            vim.api.nvim_buf_delete(buf_info.buf, {force = true})
        end

        -- swap all the tmp windows over to the new buf.
        for _, buf_info in ipairs(buffers_to_rename) do
            local new_path = lib_path.swap_path_prefix(
                buf_info.path,
                old_dir,
                new_dir
            )
            for _, win in ipairs(buf_info.wins) do
                vim.api.nvim_set_current_win(win)
                vim.cmd('silent edit ' .. new_path)
            end
        end
    end
end

-- rename will rename the file associated with the provided
-- node.
--
-- if the original file (before rename) is opened in a neovim
-- window the buffer will first be written to disk, then
-- renamed, and then any windows referencing the original buffer
-- will have that buffer swapped with the renamed one.
--
-- this sequence avoids annoying situations like with `nnn` plugins
-- where the original buffer sticks around in neovim.
function M.rename(node, component_state, cb)
    if node.filetree_item == nil then
        return
    end
    local rename = function(input)
        if input == nil then
            return
        end
        local cur_tabpage = vim.api.nvim_get_current_tabpage()
        local path = node.filetree_item.uri
        local parent_dir = lib_path.parent_dir(lib_path.strip_file_prefix(path))
        local rename_path = parent_dir .. input

        local perms = vim.fn.getfperm(rename_path)
        if perms ~= "" then
            vim.ui.input(
            {
                prompt = string.format("\r%s exists, pick a new name or operation will be canceled: ", rename_path),
                default = input,
            },
            function(new_basename)
                if new_basename == nil or new_basename == "" then
                    return
                end
                rename_path = parent_dir .. new_basename
            end)
        end

        local rename_cb = nil
        if node.filetree_item.is_dir then
            rename_cb = rename_dir_helper(path, rename_path)
        else
            rename_cb = rename_file_helper(path, rename_path)
        end

        if vim.fn.rename(path, rename_path) == -1 then
            return
        end

        local t = lib_tree.get_tree(component_state.tree)
        local dpt = t.depth_table
        builder.build_filetree_recursive(t.root, component_state, dpt)
        cb()

        rename_cb()

        vim.api.nvim_set_current_tabpage(cur_tabpage)
    end
    vim.ui.input({prompt = "Rename file to: "},
        rename
    )
end

-- mv_selected will move the currently selected node
-- into the directory or parent directory of the incoming `node`.
function M.mv_selected(node, component_state, cb)
    if selected_node == nil then
        lib_notify.notify_popup_with_timeout("No file selected.", 7500, "error")
        return
    end
    local parent_dir = ""
    local selected_file = M.resolve_file_name(selected_node.filetree_item.uri)
    if node.filetree_item.is_dir then
        parent_dir = node.filetree_item.uri .. '/'
        node.expanded = true
    else
        parent_dir = M.resolve_parent_directory(node.filetree_item.uri)
    end

    local from = selected_node.filetree_item.uri
    local to = parent_dir .. selected_file

    local perms = vim.fn.getfperm(to)
    if perms ~= "" then
        vim.ui.input(
        {
            prompt = string.format("\r%s exists, rename it or operation will cancel. Provide no input to cancel operation: ", to),
            default = selected_file,
        },
        function(new_basename)
            if new_basename == nil or new_basename == "" then
                return
            end
            to = parent_dir .. new_basename
            vim.fn.rename(from, to)
        end)
    else
        vim.fn.rename(from, to)
    end

    -- if node is a dir expand it, since we just
    -- created something in it
    if node.is_dir then
        node.expanded = true
    end

    local t = lib_tree.get_tree(component_state.tree)
    local dpt = t.depth_table
    builder.build_filetree_recursive(t.root, component_state, dpt)
    cb()
    M.deselect(component_state)
end

-- recursive_cp performs a recursive copy of a directory.
local function recursive_cp(existing_dir, move_to)
    if vim.fn.isdirectory(existing_dir) == 1 then
        local basename = M.resolve_file_name(existing_dir)
        local to_create = move_to .. '/' .. basename
        move_to = move_to .. '/' .. basename
        vim.fn.mkdir(to_create, 'p')
    end
    for _, file in ipairs(vim.fn.readdir(existing_dir)) do
        local to_check = existing_dir .. '/' .. file
        if vim.fn.isdirectory(to_check) == 1 then
            recursive_cp(to_check, move_to)
        else
            local basename = M.resolve_file_name(to_check)
            local to_create = move_to .. '/' .. basename
            local perms = vim.fn.getfperm(to_create)
            if perms ~= "" then
                vim.ui.input(
                {
                    prompt = string.format("\r%s exists inside %s, rename it or overwrite. Provide no input to cancel operation: ", basename, move_to),
                    default = basename,

                },
                function(new_basename)
                    if new_basename == nil or new_basename == "" then
                        return
                    end
                    to_create = move_to .. '/' .. new_basename
                    vim.fn.writefile(vim.fn.readfile(to_check), to_create)
                end)
            else
                vim.fn.writefile(vim.fn.readfile(to_check), to_create)
            end
        end
    end
end

-- cp_selected will copy the currently selected node.
--
-- if the node is a directory a recursive copy will be
-- performed.
function M.cp_selected(node, component_state, cb)
    if selected_node == nil then
        lib_notify.notify_popup_with_timeout("No file selected.", 7500, "error")
        return
    end
    -- the new directory we want to move `selected_node` to, including
    -- the trailing slash.
    local move_to = ""
    if node.filetree_item.is_dir then
        move_to = node.filetree_item.uri .. '/'
        node.expanded = true
    else
        move_to = M.resolve_parent_directory(node.filetree_item.uri)
    end

    if not selected_node.filetree_item.is_dir then
        local fname = M.resolve_file_name(selected_node.filetree_item.uri)
        local from = selected_node.filetree_item.uri
        local to = move_to .. fname
        local perms = vim.fn.getfperm(to)
        if perms ~= "" then
            vim.ui.input(
            {
                prompt = string.format("\r%s exists, rename it or overwrite. Provide no input to cancel operation: ", fname),
                default = fname,

            },
            function(new_basename)
                if new_basename == nil or new_basename == "" then
                    return
                end
                to = move_to .. new_basename
                vim.fn.writefile(vim.fn.readfile(from), to)
            end)
        else
            if vim.fn.writefile(vim.fn.readfile(from), to) == -1 then
                return
            end
        end
    else
        recursive_cp(selected_node.filetree_item.uri, move_to)
    end

    -- if node is a dir expand it, since we just
    -- created something in it
    if node.is_dir then
        node.expanded = true
    end

    local t = lib_tree.get_tree(component_state.tree)
    local dpt = t.depth_table
    builder.build_filetree_recursive(t.root, component_state, dpt)
    cb()
    M.deselect(component_state)
end

-- filetree_ops switches the provided op to the correct
-- handling function.
--
-- input for any filetree operation is handled by vim.ui.input
-- if required.
M.filetree_ops = function(opt)
    local ctx = ui_req_ctx()
    if ctx.state == nil or ctx.cursor == nil then
        return
    end
    if ctx.node == nil then
        return
    end

    if opt == "select" then
        M.select(ctx.node, ctx.state["filetree"])
        lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
    end
    if opt == "deselect" then
        M.deselect(ctx.state["filetree"])
        lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
    end
    if opt == "touch" then
        M.touch(ctx.node, ctx.state["filetree"], function()
            lib_tree.write_tree(
                ctx.state["filetree"].buf,
                ctx.state["filetree"].tree,
                marshal_func
            )
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "mkdir" then
        M.mkdir(ctx.node, ctx.state["filetree"], function()
            lib_tree.write_tree(
                ctx.state["filetree"].buf,
                ctx.state["filetree"].tree,
                marshal_func
            )
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "rm" then
        M.rm(ctx.node, ctx.state["filetree"], function()
            lib_tree.write_tree(
                ctx.state["filetree"].buf,
                ctx.state["filetree"].tree,
                marshal_func
            )
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "rename" then
        M.rename(ctx.node, ctx.state["filetree"], function()
            lib_tree.write_tree(
                ctx.state["filetree"].buf,
                ctx.state["filetree"].tree,
                marshal_func
            )
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "mv" then
        M.mv_selected(ctx.node, ctx.state["filetree"], function()
            lib_tree.write_tree(
                ctx.state["filetree"].buf,
                ctx.state["filetree"].tree,
                marshal_func
            )
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "cp" then
        M.cp_selected(ctx.node, ctx.state["filetree"], function()
            lib_tree.write_tree(
                ctx.state["filetree"].buf,
                ctx.state["filetree"].tree,
                marshal_func
            )
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "exec_perm" then
        M.toggle_exec_perm(ctx.node)
    end
end

function M.toggle_exec_perm(node)
    local cur_perms = vim.fn.getfperm(node.filetree_item.uri)
    local exec_bit = vim.fn.strpart(cur_perms, 2, 1)
    if exec_bit == "x" then
        vim.fn.system("chmod u-x " .. node.filetree_item.uri)
    else
        vim.fn.system("chmod u+x " .. node.filetree_item.uri)
    end
end

function M.cd_up()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must open a filetree first with LTOpenFiletree command", 7500, "error")
        return
    end
    local t = lib_tree.get_tree(ctx.state["filetree"].tree)
    if t.root == nil then
        return
    end
    local parent_dir = lib_path.parent_dir(lib_path.strip_file_prefix(
        t.root.location.uri
    ))
    parent_dir = lib_path.strip_trailing_slash(parent_dir)
    handlers.filetree_handler(parent_dir)
end

function M.cd()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil or
        ctx.node == nil
    then
        lib_notify.notify_popup_with_timeout("Must open a filetree first with LTOpenFiletree command", 7500, "error")
        return
    end
    if not ctx.node.filetree_item.is_dir then
        lib_notify.notify_popup_with_timeout("Cannot 'cd' a regular file", 7500, "error")
        return
    end
    local new_dir = lib_path.strip_file_prefix(ctx.node.location.uri)
    handlers.filetree_handler(new_dir)
end

function M.navigation(dir)
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end
    if dir == "n" then
        lib_navi.next(ctx.state["filetree"])
    elseif dir == "p" then
        lib_navi.previous(ctx.state["filetree"])
    end
    vim.cmd("redraw!")
end

function M.details_filetree()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must open a filetree first with LTOpenFiletree command", 7500, "error")
        return
    end
    lib_details.details_popup(ctx.state, ctx.node, details_func)
end

function M.on_tab_closed(tab)
    local state = lib_state.get_state[tab]
    if state == nil then
        return
    end
    lib_tree.remove_tree(state["filetree"].tree)
end

function M.help(display)
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must open a filetree first with LTOpenFiletree command", 7500, "error")
        return
    end
    if display then
        vim.api.nvim_win_set_buf(ctx.state["filetree"].win, filetree_help_buf.help_buffer)
    else
        vim.api.nvim_win_set_buf(ctx.state["filetree"].win, ctx.state["filetree"].buf)
    end
end

function M.dump_tree()
    local ctx = ui_req_ctx()
    if ctx.tree_handle == nil then
        return
    end
    lib_tree.dump_tree(lib_tree.get_tree(ctx.tree_handle).root)
end

function M.dump_node()
    local ctx = ui_req_ctx()
    lib_tree.dump_tree(ctx.node)
end

local function merge_configs(user_config)
    -- merge keymaps
    if user_config.keymaps ~= nil then
        for k, v in pairs(user_config.keymaps) do
            config.keymaps[k] = v
        end
    end

    -- merge top levels
    for k, v in pairs(user_config) do
        if k == "keymaps" then
            goto continue
        end
        config[k] = v
        ::continue::
    end
end

function M.setup(user_config)
    local function pre_window_create(state)
        local tab = vim.api.nvim_get_current_tabpage()
        local cur_win = vim.api.nvim_get_current_win()
        -- unlike the other trees, we want invoked jumps
        -- to open the file in the last focused window.
        -- this updates the invoking window when the
        -- filetree is first opened.
        if cur_win ~= state["filetree"].win and not lib_util_win.is_component_win(tab, cur_win) then
            state["filetree"].invoking_win = cur_win
        end
        local buf_name = "explorer"
        state["filetree"].buf =
            filetree_buf._setup_buffer(buf_name, state["filetree"].buf, state["filetree"].tab)
        if state["filetree"].tree == nil then
            return false
        end
        lib_tree.write_tree(
            state["filetree"].buf,
            state["filetree"].tree,
            marshal_func
        )
        return true
    end

    local function post_window_create()
        if config.use_web_devicons then
            local devicons = require("nvim-web-devicons")
            for _, icon_data in pairs(devicons.get_icons()) do
                local hl = "DevIcon" .. icon_data.name
                vim.cmd(string.format("syn match %s /%s/", hl, icon_data.icon))
            end
        end
        -- set scrolloff to 9999 to keep items centered
        vim.api.nvim_win_set_option(vim.api.nvim_get_current_win(), "scrolloff", 9999)
    end

    -- merge in config
    if user_config ~= nil then
        merge_configs(user_config)
    end

    if not pcall(require, "litee.lib") then
        lib_notify.notify_popup_with_timeout("Cannot start litee-filetree without the litee.lib library.", 7500, "error")
        return
    end

    if not pcall(require, "nvim-web-devicons") and config.use_web_devicons then
        lib_notify.notify_popup_with_timeout(
            "Litee-filetree is configured to use nvim-web-devicons but the module is not loaded.", 7500, "error")
    else
        -- setup the dir icon and file type.
        local devicons = require("nvim-web-devicons")
        require("nvim-web-devicons").set_icon({
          ["dir"] = {
            icon = "",
            color = "#6d8086",
            cterm_color = "108",
            name = "Directory",
          },
        })
        devicons.set_up_highlights()
    end

    lib_panel.register_component("filetree", pre_window_create, post_window_create)

    -- will enable filetree file tracking with source code buffers.
    vim.cmd([[au WinEnter,CursorHold,CursorHoldI * lua require('litee.filetree.autocmds').file_tracking()]])

    require('litee.filetree.commands').setup()
end

return M
