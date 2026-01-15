local M = {}

M.names = {
    body = "block",
}

function M.log_item(item_name)
    return string.format("print(%s)", item_name)
end

return M
