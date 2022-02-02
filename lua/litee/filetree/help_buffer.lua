local config            = require('litee.filetree.config').config

local M = {}
-- _setup_help_buffer performs an idempotent creation
-- of the filetree help buffer
--
-- help_buf_handle : previous filetree help buffer handle
-- or nil
--
-- returns:
--   "buf_handle"  -- handle to a valid filetree help buffer
function M._setup_help_buffer(help_buf_handle)
    if
        help_buf_handle == nil
        or not vim.api.nvim_buf_is_valid(help_buf_handle)
    then
        local buf = vim.api.nvim_create_buf(false, false)
        if buf == 0 then
            vim.api.nvim_err_writeln("ui.help failed: buffer create failed")
            return
        end
        help_buf_handle = buf
        local lines = {}
        if not config.disable_keymaps then
            lines = {
                "FILETREE HELP:",
                "press '?' to close",
                "",
                "KEYMAP:",
                config.keymaps.expand .. " - expand a directory",
                config.keymaps.collapse .. " - collapse a directory",
                config.keymaps.collapse_all .. " - collapse all directories",
                config.keymaps.jump .. " - jump to file in last used window",
                config.keymaps.jump_split .. " - jump to window in a new split",
                config.keymaps.jump_vsplit .. " - jump to window in a new vertical split",
                config.keymaps.jump_tab .. " - jump to window in a new tab",
                config.keymaps.hide .. " - hide the filetree component",
                config.keymaps.close .. " - close the filetree component",
                config.keymaps.new_file .. " - create a new regular file",
                config.keymaps.delete_file .. " - delete a file or directory (recursively)",
                config.keymaps.new_dir .. " - create a new directory",
                config.keymaps.rename_file .. " - rename a file",
                config.keymaps.move_file .. " - (recursively) move a file or directory",
                config.keymaps.copy_file .. " - (recursively) copy a file or directory",
                config.keymaps.select_file .. " - select a file for copy or move",
                config.keymaps.deselect_file .. " - deselect a selected file",
                config.keymaps.change_dir .. " - change the current directory to one under the cursor",
                config.keymaps.up_dir .. " - move up one directory",
                config.keymaps.file_details .. " - show file details",
                config.keymaps.toggle_exec_perm .. " - toggle the user exec permissions for a file",
                config.keymaps.close_panel_pop_out .. " - close the popout panel when filetree is popped out",
                config.keymaps.help .. " - show help"
            }
        else
            lines = {
                "FILETREE HELP:",
                "press '?' to close",
                "",
                "No KEYMAP set:",
            }
        end

        vim.api.nvim_buf_set_lines(help_buf_handle, 0, #lines, false, lines)
    end
    -- set buf options
    vim.api.nvim_buf_set_name(help_buf_handle, "Filetree Help")
    vim.api.nvim_buf_set_option(help_buf_handle, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(help_buf_handle, 'filetype', 'filetree')
    vim.api.nvim_buf_set_option(help_buf_handle, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(help_buf_handle, 'modifiable', false)
    vim.api.nvim_buf_set_option(help_buf_handle, 'swapfile', false)

    -- set buffer local keymaps
    local opts = {silent=true}
    vim.api.nvim_buf_set_keymap(help_buf_handle, "n", "?", ":lua require('litee.filetree').help(false)<CR>", opts)

    return help_buf_handle
end

M.help_buffer = M._setup_help_buffer(nil)

return M
