local levels = require("99.logger.level")

--- @class _99.Logger.Options
--- @field level number?
--- @field path string?
--- @field print_on_error? boolean
--- @field max_logs_cached? number
--- @field max_errors_cached? number
--- @field error_cache_level? number

--- @class _99.Logger.LoggerConfig
--- @field type? "file" | "print"
--- @field path? string
--- @field level? number
--- @field max_logs_cached? number
--- @field max_errors_cached? number
--- @field error_cache_level? number i dont know how to do enum values :)

--- @param ... any[]
--- @return string
local function stringifyArgs(...)
    local count = select("#", ...)
    local out = {}
    assert(
        count % 2 == 0,
        "you cannot call logging with an odd number of args. e.g: msg, [k, v]..."
    )
    for i = 1, count, 2 do
        local key = select(i, ...)
        local value = select(i + 1, ...)
        assert(type(key) == "string", "keys in logging must be strings")

        if type(value) == "table" then
            if type(value.to_string) == "function" then
                value = value:to_string()
            else
                value = vim.inspect(value)
            end
        elseif type(value) == "string" then
            value = string.format('"%s"', value)
        else
            value = tostring(value)
        end

        table.insert(out, string.format("%s=%s", key, value))
    end
    return table.concat(out, " ")
end

--- @class LoggerSink
--- @field write_line fun(LoggerSink, string): nil

--- @class VoidLogger : LoggerSink
local VoidLogger = {}
VoidLogger.__index = VoidLogger

function VoidLogger.new()
    return setmetatable({}, VoidLogger)
end

--- @param _ string
function VoidLogger:write_line(_) end

--- @class FileSink : LoggerSink
--- @field fd number
local FileSink = {}
FileSink.__index = FileSink

--- @param path string
--- @return LoggerSink
function FileSink:new(path)
    local fd, err = vim.uv.fs_open(path, "w", 493)
    if not fd then
        error("unable to file sink", err)
    end

    return setmetatable({
        fd = fd,
    }, self)
end

--- @param str string
function FileSink:write_line(str)
    local success, err = vim.uv.fs_write(self.fd, str .. "\n")
    if not success then
        error("unable to write to file sink", err)
    end
    vim.uv.fs_fsync(self.fd)
end

--- @class PrintSink : LoggerSink
local PrintSink = {}
PrintSink.__index = PrintSink

--- @return LoggerSink
function PrintSink:new()
    return setmetatable({}, self)
end

--- @param str string
function PrintSink:write_line(str)
    local _ = self
    print(str)
end

--- @class _99.Logger
--- @field level number
--- @field sink LoggerSink
--- @field print_on_error boolean
--- @field log_cache string[]
--- @field max_logs_cached number
--- @field max_errors_cached number
--- @field error_cache string[]
--- @field error_cache_level number
--- @field extra_params string[]
local Logger = {}
Logger.__index = Logger

--- @param level number?
function Logger:new(level)
    level = level or levels.FATAL
    return setmetatable({
        sink = VoidLogger:new(),
        level = level,
        print_on_error = false,
        log_cache = {},
        error_cache = {},
        error_cache_level = levels.FATAL,
        max_errors_cached = 5,
        max_logs_cached = 100,
    }, self)
end

function Logger:clone()
    return setmetatable({
        sink = self.sink,
        level = self.level,
        print_on_error = self.print_on_error,
        log_cache = {},
        error_cache = {},
        error_cache_level = self.error_cache_level,
        max_errors_cached = self.max_errors_cached,
        max_logs_cached = self.max_logs_cached,
    }, Logger)
end

--- @param path string
--- @return _99.Logger
function Logger:file_sink(path)
    self.sink = FileSink:new(path)
    return self
end

--- @return _99.Logger
function Logger:print_sink()
    self.sink = PrintSink:new()
    return self
end

--- @param area string
--- @return _99.Logger
function Logger:set_area(area)
    local new_logger = self:clone()
    table.insert(new_logger.extra_params, "Area")
    table.insert(new_logger.extra_params, area)
    return new_logger
end

--- @param xid number
--- @return _99.Logger
function Logger:set_id(xid)
    local new_logger = self:clone()
    table.insert(new_logger.extra_params, "id")
    table.insert(new_logger.extra_params, xid)
    return new_logger
end

--- @param level number
--- @return _99.Logger
function Logger:set_level(level)
    self.level = level
    return self
end

--- @return _99.Logger
function Logger:on_error_print_message()
    self.print_on_error = true
    return self
end

--- @param opts _99.Logger.Options?
function Logger:configure(opts)
    if not opts then
        return
    end

    if opts.level then
        self:set_level(opts.level)
    end

    if opts.path then
        self:file_sink(opts.path)
    else
        print("setting print sink")
        self:print_sink()
    end

    if opts.print_on_error then
        self:on_error_print_message()
    end

    self.max_logs_cached = opts.max_logs_cached or 100
    self.max_errors_cached = opts.max_errors_cached or 5
    self.error_cache_level = opts.error_cache_level or levels.FATAL
end

--- @param level number
--- @param line string
function Logger:_cache_log(level, line)
    if not self.log_cache then
        self.log_cache = {}
    end

    table.insert(self.log_cache, line)
    if level >= self.error_cache_level then
        table.insert(self.error_cache, line)
    end

    if #self.log_cache > self.max_logs_cached then
        table.remove(self.log_cache, 1)
    end
    if #self.error_cache > self.max_errors_cached then
        table.remove(self.error_cache, 1)
    end
end

function Logger:_log(level, msg, ...)
    if self.level > level then
        return
    end

    local args = stringifyArgs(...)
    local line =
        string.format("[%s]: %s %s", levels.levelToString(level), msg, args)
    if self.print_on_error and level == levels.ERROR then
        print(line)
    end
    self:_cache_log(level, line)
    self.sink:write_line(line)
end

--- @param msg string
--- @param ... any
function Logger:info(msg, ...)
    self:_log(levels.INFO, msg, ...)
end

--- @param msg string
--- @param ... any
function Logger:warn(msg, ...)
    self:_log(levels.WARN, msg, ...)
end

--- @param msg string
--- @param ... any
function Logger:debug(msg, ...)
    self:_log(levels.DEBUG, msg, ...)
end

--- @param msg string
--- @param ... any
function Logger:error(msg, ...)
    self:_log(levels.ERROR, msg, ...)
end

--- @param msg string
--- @param ... any
function Logger:fatal(msg, ...)
    self:_log(levels.FATAL, msg, ...)
    assert(false, "fatal msg recieved: " .. msg)
end

local module_logger = Logger:new(levels.DEBUG)

return module_logger
