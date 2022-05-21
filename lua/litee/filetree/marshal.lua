local config    = require('litee.filetree.config').config
local lib_util  = require('litee.lib.util')

local M = {}

-- provides the filename with no path details for
-- the provided uri.
local function resolve_file_name(uri)
    local final_sep = vim.fn.strridx(uri, "/")
    local dir = vim.fn.strpart(uri, final_sep+1, vim.fn.strlen(uri))
    return dir
end

-- marshal_func is a function which returns the necessary
-- values for marshalling a filetree node into a buffer
-- line.
function M.marshal_func(node)
    local icon_set = require('litee.filetree').icon_set
    local name, detail, icon = "", "", ""

    name = node.name

    -- this option will make all filetree entries show their relative paths
    -- from root. usefule for bottom/top layouts.
    if config.relative_filetree_entries then
        local file, relative = lib_util.relative_path_from_uri(node.filetree_item.uri)
        if relative then
            name = file
        end
    end

    if node.depth == 0 then
        name = resolve_file_name(node.filetree_item.uri)
    end

    -- we know unless the node is a dir, it will have no
    -- children so leave off the expand guide to display
    -- a leaf without having to evaluate this node further.
    if not node.filetree_item.is_dir then
        local node_name = node.name
        if config.use_web_devicons then
            icon = require("nvim-web-devicons").get_icon(node_name, nil, {default=true})
        else
            -- Usually `node_name` is the name of a file.
            -- Any the user actually don't need to provide a `node_name` icon.
            icon = icon_set[node_name] or ""
        end
        local expand_guide = " "
        return name, detail, icon, expand_guide
    end

    local dir = "dir"
    if config.use_web_devicons then
        icon = require("nvim-web-devicons").get_icon(dir)
    else
        icon = icon_set[dir] or dir -- The user can provide a icon for dir.
    end
    return name, detail, icon
end

return M
