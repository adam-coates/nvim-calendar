local Job = require('plenary.job')
local telescope_ok, telescope = pcall(require, 'telescope')
local pickers_ok, pickers = pcall(require, 'telescope.pickers')
local finders_ok, finders = pcall(require, 'telescope.finders')
local sorters_ok, sorters = pcall(require, 'telescope.sorters')

if not telescope_ok or not pickers_ok or not finders_ok or not sorters_ok then
    print("Telescope or its required modules (pickers, finders, sorters) not found or not loaded properly")
    return
end

-- Function to strip ANSI escape codes from the string
local function strip_ansi_codes(input)
    return input:gsub("\27%[[0-9;]*m", "")  -- Remove ANSI escape sequences
end

local function fetch_and_show_events()
    -- Get today's date in the format 'YYYY-MM-DD'
    local start_date = vim.fn.strftime("%Y-%m-%d", os.time())
    -- Calculate the date 1 month later
    local end_date = vim.fn.strftime("%Y-%m-%d", os.time{ year = os.date("%Y"), month = os.date("%m") + 1, day = os.date("%d") })

    -- Debug the calculated dates
    print("Start Date: " .. start_date)
    print("End Date: " .. end_date)

    Job:new({
        command = 'gcalcli',
        args = { 'agenda', start_date, end_date },
        on_exit = function(job, return_val)
            if return_val == 0 then
                local output = job:result()

                -- Ensure output is an array of lines if it's a single string
                if type(output) == "string" then
                    output = {}
                    for line in output:gmatch("[^\r\n]+") do
                        table.insert(output, line)
                    end
                end

                -- Clean up the output by removing ANSI codes
                local clean_output = {}
                for _, line in ipairs(output) do
                    local cleaned_line = strip_ansi_codes(line)
                    
                    -- Only insert the cleaned line if it's not empty
                    if cleaned_line ~= "" then
                        table.insert(clean_output, cleaned_line)
                    end
                end

                -- Debug output to inspect cleaned data
                print(vim.inspect(clean_output))

                -- Use vim.schedule() to defer the picker creation to the main thread
                vim.schedule(function()
                    pickers.new({
                        prompt_title = "Upcoming Events",
                        finder = finders.new_table({
                            results = clean_output,
                            entry_maker = function(entry)
                                return {
                                    value = entry,
                                    display = entry,  -- Display the cleaned output
                                    ordinal = entry,  -- Sorting based on entry
                                }
                            end,
                        }),
                        sorter = sorters.get_generic_fuzzy_sorter(),
                    }):find()
                end)
            else
                print("Error fetching events")
            end
        end,
    }):start()
end

vim.api.nvim_create_user_command("ShowEvents", function()
    fetch_and_show_events()
end, { nargs = 0 })
