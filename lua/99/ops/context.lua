local Logger = require("99.logger.logger")
local utils = require("99.utils")
local random_file = utils.random_file

--- @class _99.Context
--- @field md_file_names string[]
--- @field ai_context string[]
--- @field tmp_file string
local Context = {}
Context.__index = Context

--- @param _99 _99.State
function Context.new(_99, xid)
    local mds = {}
    for _, md in ipairs(_99.md_files) do
        table.insert(mds, md)
    end

    return setmetatable({
        md_file_names = mds,
        ai_context = {},
        tmp_file = random_file(),
    }, Context)
end

--- @param md_file_name string
--- @return self
function Context:add_md_file_name(md_file_name)
    table.insert(self.md_file_names, md_file_name)
    return self
end

--- @param location _99.Location
function Context:_read_md_files(location)
    local cwd = vim.uv.cwd()
    local dir = vim.fn.fnamemodify(location.full_path, ":h")

    while dir:find(cwd, 1, true) == 1 do
        for _, md_file_name in ipairs(self.md_file_names) do
            local md_path = dir .. "/" .. md_file_name
            local file = io.open(md_path, "r")
            if file then
                local content = file:read("*a")
                file:close()
                Logger:info("Context#adding md file to the context", "md_path", md_path)
                table.insert(self.ai_context, content)
            end
        end

        if dir == cwd then
            break
        end

        dir = vim.fn.fnamemodify(dir, ":h")
    end
end

--- @param _99 _99.State
--- @param location _99.Location
--- @return self
function Context:finalize(_99, location)
    self:_read_md_files(location)
    table.insert(self.ai_context, _99.prompts.get_file_location(location))
    table.insert(self.ai_context, _99.prompts.get_range_text(location.range))
    table.insert(self.ai_context, _99.prompts.tmp_file_location(self.tmp_file))
    return self
end

--- @param request _99.Request
function Context:add_to_request(request)
    for _, context in ipairs(self.ai_context) do
        request:add_prompt_content(context)
    end
end

return Context
