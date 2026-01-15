local M = {}

M.names = {
    body = "body_statement",
}

function M.log_item(item_name)
    return string.format("puts(%s)", item_name)
end

return M
