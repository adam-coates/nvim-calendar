-- Create the module outside of the command
local M = {}

-- Configuration
M.config = {
    calendar_cli = 'gcalcli',
    default_calendar = ''
}

-- Safe notification function
local function safe_notify(msg, level)
    vim.schedule(function()
        vim.notify(msg, level)
    end)
end

-- Validate time format (HH:MM)
local function validate_time(time_str)
    if not time_str:match("^%d%d?:%d%d$") then
        return false, "Time must be in HH:MM format"
    end

    local hours, minutes = time_str:match("(%d+):(%d+)")
    hours, minutes = tonumber(hours), tonumber(minutes)

    if not hours or hours < 0 or hours > 23 then
        return false, "Hours must be between 0 and 23"
    end
    if not minutes or minutes < 0 or minutes > 59 then
        return false, "Minutes must be between 0 and 59"
    end

    return true, string.format("%02d:%02d", hours, minutes)
end

-- Function to call Python dateparser with improved error handling
local function parse_natural_date(input)
    if input:gsub("%s+", "") == "" then
        return nil, "Date input cannot be empty"
    end

    local result = nil
    local error_msg = nil
    
    local Job = require('plenary.job')
    local job = Job:new({
        command = 'python3',
        args = { '-c', string.format([[
try:
    import dateparser
    result = dateparser.parse("%s")
    if result:
        print(result.strftime("%%Y-%%m-%%d"))
    else:
        print("ERROR: Could not parse date")
except Exception as e:
    print("ERROR: " + str(e))
]], input) },
        on_exit = function(j, return_val)
            local output = j:result()[1]
            if output and not output:match("^ERROR:") then
                result = output
            else
                error_msg = output:gsub("^ERROR:%s*", "")
            end
        end,
    })
    job:sync()

    if result then
        return result, nil
    else
        return nil, error_msg or "Failed to parse date"
    end
end

-- Validate duration
local function validate_duration(duration_str)
    duration_str = duration_str:gsub("%s+", "")
    local duration = tonumber(duration_str)
    
    if not duration then
        return nil, "Duration must be a number"
    end
    
    if duration <= 0 then
        return nil, "Duration must be positive"
    end
    
    if duration > 1440 then
        return nil, "Duration cannot exceed 24 hours (1440 minutes)"
    end
    
    return duration, nil
end

-- Add event using gcalcli
function M.add_event(data, calendar)
    if not data.title or data.title:gsub("%s+", "") == "" then
        safe_notify("Event title cannot be empty", vim.log.levels.ERROR)
        return
    end

    local datetime = data.date .. " " .. data.time
    local selected_calendar = calendar or M.config.default_calendar

    local Job = require('plenary.job')
    Job:new({
        command = M.config.calendar_cli,
        args = {
            '--calendar', selected_calendar,
            'add',
            '--title', data.title,
            '--when', datetime,
            '--duration', tostring(data.duration),
            '--noprompt'
        },
        on_exit = function(j, return_val)
            if return_val == 0 then
                safe_notify("Event added to " .. selected_calendar .. " successfully!", vim.log.levels.INFO)
            else
                local error_msg = table.concat(j:stderr_result(), "\n") or "Unknown error"
                vim.schedule(function()
                    safe_notify("Failed to add event: " .. error_msg, vim.log.levels.ERROR)
                end)
            end
        end,
    }):start()
end

-- Close form function
function M.close_form(bufnr, win_id)
    vim.api.nvim_win_close(win_id, true)
    vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Create the input form
local function create_event_form(selected_calendar)
    local popup = require('plenary.popup')
    local width = 60
    local height = 10
    local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }

    local bufnr = vim.api.nvim_create_buf(false, true)
    local win_id = popup.create(bufnr, {
        title = "Add Calendar Event",
        borderchars = borderchars,
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        line = math.floor((vim.o.lines - height) / 2),
    })

    local content = {
        "Title: ",
        "Date (natural input): ",
        "Time (HH:MM): ",
        "Duration (minutes): ",
        "",
        "Press <Enter> on each line to confirm entry",
        "Press <Esc> to cancel"
    }

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'acwrite')
    vim.api.nvim_win_set_cursor(win_id, { 1, 7 })

    local form_data = { title = "", date = "", time = "", duration = "" }

    -- Handle field input
    local function handle_field_input()
        local line = vim.api.nvim_win_get_cursor(win_id)[1]
        local content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]

        if line == 1 then
            local title = content:gsub("Title: ", "")
            if title:gsub("%s+", "") == "" then
                safe_notify("Title cannot be empty", vim.log.levels.ERROR)
                return
            end
            form_data.title = title
            vim.api.nvim_win_set_cursor(win_id, { 2, 22 })
        elseif line == 2 then
            local date_input = content:gsub("Date %(natural input%)%: ", "")
            local date, date_error = parse_natural_date(date_input)
            if date_error then
                safe_notify(date_error, vim.log.levels.ERROR)
                return
            end
            form_data.date = date
            vim.api.nvim_win_set_cursor(win_id, { 3, 13 })
        elseif line == 3 then
            local time_input = content:gsub("Time %(HH:MM%)%: ", "")
            local valid, time_or_error = validate_time(time_input)
            if not valid then
                safe_notify(time_or_error, vim.log.levels.ERROR)
                return
            end
            form_data.time = time_or_error
            vim.api.nvim_win_set_cursor(win_id, { 4, 19 })
        elseif line == 4 then
            local duration_input = content:gsub("Duration %(minutes%)%: ", "")
            local duration, duration_error = validate_duration(duration_input)
            if duration_error then
                safe_notify(duration_error, vim.log.levels.ERROR)
                return
            end
            form_data.duration = duration
            M.add_event(form_data, selected_calendar)
            M.close_form(bufnr, win_id)
        end
    end

    -- Set up key mappings
    vim.keymap.set('i', '<CR>', handle_field_input, { buffer = bufnr })
    vim.keymap.set('n', '<CR>', handle_field_input, { buffer = bufnr })
    vim.keymap.set('n', '<Esc>', function() M.close_form(bufnr, win_id) end, { buffer = bufnr })

    vim.cmd('startinsert!')
end

-- Select Calendar Function
local function select_calendar(callback)
    local Job = require('plenary.job')
    Job:new({
        command = M.config.calendar_cli,
        args = { 'list' },
        on_exit = function(job, return_val)
            if return_val == 0 then
                local output = job:result()
                local calendars = {}

                local function remove_ansi_escape_codes(str)
                    return str:gsub("\27%[[%d;]*[mGKH]?", "")
                end

                for _, line in ipairs(output) do
                    local clean_line = remove_ansi_escape_codes(line)
                    local calendar_name = clean_line:match("owner%s+(.+)")
                    if calendar_name and calendar_name ~= "" then
                        table.insert(calendars, calendar_name)
                    end
                end

                vim.ui.select(calendars, {
                    prompt = 'Select Calendar:',
                    format_item = function(item)
                        return item
                    end
                }, function(selected)
                    if selected then
                        callback(selected)
                    else
                        safe_notify("No calendar selected", vim.log.levels.ERROR)
                    end
                end)
            else
                safe_notify("Failed to fetch calendar list!", vim.log.levels.ERROR)
            end
        end,
    }):start()
end

-- Main function to add a calendar event
function M.add_calendar_event()
    select_calendar(function(calendar)
        create_event_form(calendar)
    end)
end

-- Create the command
vim.api.nvim_create_user_command("AddGoogleEventui", function()
    M.add_calendar_event()
end, {})
