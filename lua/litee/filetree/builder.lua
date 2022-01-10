local lib_tree          = require('litee.lib.tree')
local lib_tree_node     = require('litee.lib.tree.node')

local M = {}

-- expand expands a filetree_item in the tree, refreshing the sub directory
-- incase new content exists.
function M.expand(root, component_state)
    root.expanded = true
    local children = {}
    local files = vim.fn.readdir(root.filetree_item.uri)
    for _, child in ipairs(files) do
        local uri = root.filetree_item.uri .. "/" .. child
        local is_dir = vim.fn.isdirectory(uri)
        local child_node = lib_tree_node.new_node(child, uri, 0)
        child_node.filetree_item = {
            uri = uri,
            is_dir = (function() if is_dir == 0 then return false else return true end end)()
        }
        local range = {}
        range["start"] = { line = 0, character = 0}
        range["end"] = { line = 0, character = 0}
        child_node.location = {
            uri = "file://" .. child_node.filetree_item.uri,
            range = range
        }
        table.insert(children, child_node)
    end
    lib_tree.add_node(component_state.tree, root, children)
end

function M.build_filetree_recursive(root, component_state, old_dpt, expand_dir)
    root.children = {}
    local old_node = nil
    if old_dpt ~= nil then
        old_node = lib_tree.search_dpt(old_dpt, root.depth, root.key)
    end
    if old_node == nil then
        -- just makes it easier to shove into the if clause below.
        old_node = {}
    end
    local should_expand = false
    -- if we are provided a directory to expand check
    -- if the current root in the path to it and if so
    -- mark it for expansion.
    if expand_dir ~= nil and expand_dir ~= "" then
        local idx = vim.fn.stridx(expand_dir, root.filetree_item.uri)
        if idx ~= -1 then
            should_expand = true
        end
    end
    if
        root.depth == 0 or
        old_node.expanded or
        should_expand
    then
        M.expand(root, component_state)
    end
    for _, child in ipairs(root.children) do
        if child.filetree_item.is_dir then
            M.build_filetree_recursive(child, component_state, old_dpt, expand_dir)
        end
    end
end

return M
