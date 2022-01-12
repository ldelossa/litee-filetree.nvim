local M = {}

function M.details_func(_, node)
    local lines = {}
    table.insert(lines, "=== File Tree Item ===")
    table.insert(lines, string.format("File: %s", node.filetree_item.uri))
    table.insert(lines, string.format("Type: %s", vim.fn.getftype(node.filetree_item.uri)))
    table.insert(lines, string.format("Permissions: %s", vim.fn.getfperm(node.filetree_item.uri)))
    return lines
end

return M
