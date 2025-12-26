local geo = require("99.geo")
local Point = geo.Point
local Logger = require("99.logger.logger")
local Request = require("99.request")
local Mark = require("99.ops.marks")
local Context = require("99.ops.context")
local editor = require("99.editor")
local RequestStatus = require("99.ops.request_status")
local Window = require("99.window")

--- @param res string
--- @param location _99.Location
local function update_file_with_changes(res, location)
    local buffer = location.buffer
    local mark = location.marks.function_location

    assert(
        mark and buffer,
        "mark and buffer have to be set on the location object"
    )

    local func_start = Point.from_mark(mark)
    local ts = editor.treesitter
    local func = ts.containing_function(buffer, func_start)

    if not func then
        Logger:error(
            "update_file_with_changes: unable to find function at mark location"
        )
        error(
            "update_file_with_changes: unable to find function at mark location"
        )
        return
    end

    local lines = vim.split(res, "\n")
    func:replace_text(lines)
end

--- @param _99 _99.State
--- @param xid number
local function fill_in_function(_99, xid)
    local logger = Logger:set_area("fill_in_function"):set_id(xid)
    local ts = editor.treesitter
    local buffer = vim.api.nvim_get_current_buf()
    local cursor = Point:from_cursor()
    local func = ts.containing_function(buffer, cursor)

    if not func then
        logger:fatal("fill_in_function: unable to find any containing function")
        return
    end

    local location = editor.Location.from_range(func.function_range)
    local virt_line_count = _99.ai_stdout_rows
    if virt_line_count >= 0 then
        location.marks.function_location = Mark.mark_func_body(buffer, func)
    end

    local context = Context.new(_99):finalize(_99, location)
    local request = Request.new({
        xid = xid,
        provider = _99.provider_override,
        model = _99.model,
        tmp_file = context.tmp_file,
    })

    context:add_to_request(request)
    request:add_prompt_content(_99.prompts.prompts.fill_in_function)

    local request_status = RequestStatus.new(
        250,
        _99.ai_stdout_rows,
        "Loading",
        location.marks.function_location
    )
    request_status:start()

    local active_request = -1
    local function clean_up()
        location:clear_marks()
        request:cancel()
        request_status:stop()
        _99:remove_active_request(active_request)
    end
    active_request = _99:add_active_request(clean_up)

    request:start({
        on_stdout = function(line)
            request_status:push(line)
        end,
        on_complete = function(status, response)
            request_status:stop()
            if status == "failed" then
                if _99.display_errors then
                    Window.display_error(
                        "Error encountered while processing fill_in_function\n"
                            .. (
                                response
                                or "No Error text provided.  Check logs"
                            )
                    )
                end
                logger:error(
                    "unable to fill in function, enable and check logger for more details"
                )
            elseif status == "cancelled" then
                logger:debug("fill_in_function was cancelled")
                -- TODO: small status window here
            elseif status == "success" then
                update_file_with_changes(response, location)
            end
            clean_up()
        end,
        on_stderr = function(line)
            logger:debug("fill_in_function#on_stderr", "line", line)
        end,
    })
end

return fill_in_function
