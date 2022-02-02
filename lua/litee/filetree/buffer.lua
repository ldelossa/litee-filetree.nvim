local config = require('litee.filetree.config').config
local panel_config = require('litee.lib.config').config["panel"]
local lib_util_buf = require('litee.lib.util.buffer')

local M = {}

-- _setup_buffer performs an idempotent creation of
-- a filetree buffer.
function M._setup_buffer(name, buf, tab)
    -- see if we can reuse a buffer that currently exists.
    if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
        buf = vim.api.nvim_create_buf(false, false)
        if buf == 0 then
            vim.api.nvim_err_writeln("filetree.buffer: buffer create failed")
            return
        end
    else
        return buf
    end

    -- set buf options
    vim.api.nvim_buf_set_name(buf, name .. ":" .. tab)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(buf, 'filetype', 'filetree')
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'textwidth', 0)
    vim.api.nvim_buf_set_option(buf, 'wrapmargin', 0)

    -- set buffer local keymaps
    local opts = {silent=true}
    if not config.disable_keymaps then 
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.expand, ":LTExpandFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.collapse, ":LTCollapseFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.collapse_all, ":LTCollapseAllFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.jump, ":LTJumpFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.jump_split, ":LTJumpFiletreeSplit<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.jump_vsplit, ":LTJumpFiletreeVSplit<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.jump_tab, ":LTJumpFiletreeTab<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.hide, ":LTHideFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.close, ":LTCloseFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.new_file, ":LTTouchFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.delete_file, ":LTRemoveFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.new_dir, ":LTMkdirFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.rename_file, ":LTRenameFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.move_file, ":LTMoveFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.copy_file, ":LTCopyFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.select_file, ":LTSelectFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.deselect_file, ":LTDeSelectFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.change_dir, ":LTChangeDirFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.up_dir, ":LTUpDirFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.file_details, ":LTDetailsFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.toggle_exec_perm, ":LTToggleExecFiletree<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.close_panel_pop_out, ":LTClosePanelPopOut<CR>", opts)
        vim.api.nvim_buf_set_keymap(buf, "n", config.keymaps.help, ":lua require('litee.filetree').help(true)<CR>", opts)
    end
	if config.map_resize_keys then
           lib_util_buf.map_resize_keys(panel_config.orientation, buf, opts)
    end
    return buf
end

return M
