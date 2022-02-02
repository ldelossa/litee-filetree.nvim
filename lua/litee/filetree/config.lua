local M = {}

M.config = {
    jump_mode   = "invoking",
    no_hls      = false,
    select_hi   = "LTSelectFiletree",
    map_resize_keys = true,
    use_web_devicons = true,
    relative_filetree_entries = false,
    on_open = "popup",
    current_file_hl = "LTCurrentFileFiletree",
    disable_keymaps = false,
    keymaps = {
        expand = "zo",
        collapse = "zc",
        collapse_all = "zM",
        jump = "<CR>",
        jump_split = "s",
        jump_vsplit = "v",
        jump_tab = "t",
        hide = "H",
        close = "X",
        new_file = "n",
        delete_file = "D",
        new_dir = "d",
        rename_file = "r",
        move_file = "m",
        copy_file = "p",
        select_file = "<Space>",
        deselect_file = "<Space><Space>",
        change_dir = "cd",
        up_dir = "..",
        file_details = "i",
        toggle_exec_perm = "*",
        close_panel_pop_out = "<Esc>",
        help = "?"
    },
}

return M
