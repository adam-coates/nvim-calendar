vim.api.nvim_create_user_command("AddGoogleEventui", function()
    local popup = require('plenary.popup')
    local Job = require('plenary.job')

    local M = {}

    -- Configuration
    local config = {
        calendar_cli = 'gcalcli',
        default_calendar = ''
    }

    -- Safe notification function
    local function safe_notify(msg, level)
        vim.schedule(function()
            vim.notify(msg, level)
        end)
    end

    -- Function to call Python dateparser
    local function parse_natural_date(input)
        local result = nil
        local job = Job:new({
            command = 'python3',
            args = { '-c', string.format([[
import dateparser
result = dateparser.parse("%s")
print(result.strftime("%%Y-%%m-%%d") if result else "ERROR")
]], input) },
            on_exit = function(j, return_val)
                local output = j:result()[1]
                if output and output ~= "ERROR" then
                    result = output
                else
                    safe_notify("Invalid date input: " .. input, vim.log.levels.ERROR)
                end
            end,
        })
        job:sync()
        return result
    end

    -- Add event using gcalcli
    M.add_event = function(data, calendar)
        local datetime = data.date .. " " .. data.time
        local selected_calendar = calendar or config.default_calendar

        -- Log the event data for debugging
        safe_notify("Adding event with data: " .. vim.inspect(data), vim.log.levels.DEBUG)

        Job:new({
            command = config.calendar_cli,
            args = {
                '--calendar', selected_calendar,
                'add',
                '--title', data.title,
                '--when', datetime,
                '--duration', data.duration,
                '--noprompt'
            },
            on_exit = function(j, return_val)
                if return_val == 0 then
                    safe_notify("Event added to " .. selected_calendar .. " successfully!", vim.log.levels.INFO)
                else
                    -- Capture stderr and display error message using vim.schedule to avoid event loop issues
                    local error_msg = j:stderr_result()[1] or "Unknown error"
                    vim.schedule(function()
                        safe_notify("Failed to add event! Error: " .. error_msg, vim.log.levels.ERROR)
                        -- Additional debugging: Log the error output
                        vim.api.nvim_err_writeln("gcalcli stderr: " .. error_msg)
                    end)
                end
            end,
        }):start()
    end

    -- Select Calendar Function using vim.ui.select
    local function select_calendar(callback)
        -- Get the list of available calendars using gcalcli
        Job:new({
            command = config.calendar_cli,
            args = { 'list' },
            on_exit = function(job, return_val)
                if return_val == 0 then
                    -- Parse the output to extract calendar names
                    local output = job:result()
                    local calendars = {}

                    -- Function to remove ANSI escape sequences (color codes)
                    local function remove_ansi_escape_codes(str)
                        return str:gsub("\27%[[%d;]*[mGKH]?", "")
                    end

                    -- Process each line and clean it
                    for _, line in ipairs(output) do
                        -- Clean each calendar entry and capture the calendar name
                        local clean_line = remove_ansi_escape_codes(line)
                        local calendar_name = clean_line:match("owner%s+(.+)")  -- Get calendar name after "owner"
                        if calendar_name and calendar_name ~= "" then
                            table.insert(calendars, calendar_name)
                        end
                    end

                    -- Use vim.ui.select to let the user pick a calendar
                    vim.ui.select(calendars, {
                        prompt = 'Select Calendar:',
                        format_item = function(item)
                            return item  -- Clean calendar names
                        end
                    }, function(selected)
                        -- Pass the selected calendar back to the callback
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

    -- Create the input form
    local function create_event_form(selected_calendar)
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
                form_data.title = content:gsub("Title: ", "")
                vim.api.nvim_win_set_cursor(win_id, { 2, 22 })
            elseif line == 2 then
                form_data.date = parse_natural_date(content:gsub("Date %(natural input%)%: ", ""))
                vim.api.nvim_win_set_cursor(win_id, { 3, 13 })
            elseif line == 3 then
                form_data.time = content:gsub("Time %(HH:MM%)%: ", "")
                vim.api.nvim_win_set_cursor(win_id, { 4, 19 })
            elseif line == 4 then
                -- Clean the duration input
                local duration_str = content:gsub("Duration %(minutes%)%: ", ""):gsub("%s+", "")
                
                -- Ensure the duration is a valid number
                local duration = tonumber(duration_str)
                
                if not duration or duration <= 0 then
                    safe_notify("Duration must be a positive number", vim.log.levels.ERROR)
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

    -- Main function to add a calendar event
    M.add_calendar_event = function()
        select_calendar(function(calendar)
            create_event_form(calendar)
        end)
    end

    function M.close_form(bufnr, win_id)
        vim.api.nvim_win_close(win_id, true)
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    -- Call the function to create the event form
    M.add_calendar_event()
end, {})
