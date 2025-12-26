local Logger = require("99.logger.logger")
local Request = require("99.request")
local Location = require("99.editor.location")
local Context = require("99.ops.context")
local RequestStatus = require("99.ops.request_status")
local Mark = require("99.ops.marks")
local Range = require("99.geo").Range

--- @param _99 _99.State
--- @param range _99.Range
local function visual(_99, range)
    local location = Location.from_range(range)
    local context = Context.new(_99):finalize(_99, location)
    local request = Request.new({
        tmp_file = context.tmp_file,
        model = _99.model,
        provider = _99.provider_override,
    })
    local top_mark, bottom_mark = Mark.mark_range(range)
    location.marks.top_mark = top_mark
    location.marks.bottom_mark = bottom_mark

    local display_ai_status = _99.ai_stdout_rows > 1
    local top_status = RequestStatus.new(250, _99.ai_stdout_rows or 1, "Implementing...")
    local bottom_status = RequestStatus.new(250, 1, "Implementing...")

    local clean_up_id = -1
    local function clean_up()
        top_status:stop()
        bottom_status:stop()
        location:clear_marks()
        _99:remove_active_request(clean_up_id)
    end
    clean_up_id = _99:add_active_request(function()
        clean_up()
        request:cancel()
    end)

    context:add_to_request(request)
    request:add_prompt_content(_99.prompts.prompts.visual_selection)

    top_status:start()
    bottom_status:start()
    request:start({
        on_complete = function(status, response)
            if status == "cancelled" then
                Logger:debug("request cancelled for visual selection, removing marks")
            elseif status == "failed" then
                Logger:error("request failed for visual_selection", "error response", response or "no response provided")
            elseif status == "success" then
                local valid = top_mark:is_valid() and bottom_mark:is_valid()
                if not valid then
                    Logger:fatal("the original visual_selection has been destroyed.  You cannot delete the original visual selection during a request")
                end
                local new_range = Range.from_marks(top_mark, bottom_mark)
                local lines = vim.split(response, "\n")
                new_range:replace_text(lines)
            end
            clean_up()
        end,
        on_stdout = function(line)
            if display_ai_status then
                top_status:push(line)
            end
        end,
        on_stderr = function(line)
            Logger:debug("visual_selection#on_stderr received", "line", line)
        end
    })
end

return visual
