local api = vim.api

-- Define constants
local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local week_days = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }

-- Check if year is leap
local function is_leap_year(year)
	if year % 400 == 0 then
		return true
	elseif year % 100 == 0 then
		return false
	elseif year % 4 == 0 then
		return true
	else
		return false
	end
end

-- Get number of days in a given month of a year
local function get_days_in_month(month, year)
	if month == 2 and is_leap_year(year) then
		return 29
	else
		return days_in_month[month]
	end
end

-- Calculate day of the week for the 1st of a given month and year
local function calculate_start_day(month, year)
	local d = 1
	local m = (month + 9) % 12 + 1
	local y = year - math.floor((m - 3) / 10)
	local k = y % 100
	local j = math.floor(y / 100)
	local day = (d + math.floor(2.6 * m - 0.2) - 2 * j + k + math.floor(k / 4) + math.floor(j / 4)) % 7
	return day
end

-- Create a string representing the calendar for a given month and year
local function create_month_calendar(month, year)
	local days = get_days_in_month(month, year)
	local start_day = calculate_start_day(month, year)
	local calendar = {}

	local header = string.format("%s %d", months[month], year)
	table.insert(calendar, string.rep(" ", math.floor((20 - #header) / 2)) .. header)
	table.insert(calendar, table.concat(week_days, " "))

	local line = string.rep("   ", start_day)
	for day = 1, days do
		line = line .. string.format("%2d ", day)
		if (#line / 3) % 7 == 0 then
			table.insert(calendar, line)
			line = ""
		end
	end
	if #line > 0 then
		table.insert(calendar, line)
	end

	return calendar
end

-- Setup mouse click mappings for the calendar
local function setup_day_click_mappings(buffer, start_month, start_year)
	-- Clear existing key mappings for the buffer
	api.nvim_buf_clear_namespace(buffer, 0, 0, -1)

	-- Set mapping for Enter key to use the selected day based on cursor position
	api.nvim_buf_set_keymap(
		buffer,
		"n",
		"<CR>",
		":lua require('nvim-calendar.get-events').on_day_click()<CR>",
		{ noremap = true, silent = true }
	)
end

-- Function to display multiple months in a buffer
local function display_calendar(start_month, start_year, months_to_show)
	local buffer = api.nvim_create_buf(false, true)

	-- Set buffer options
	api.nvim_buf_set_option(buffer, "bufhidden", "wipe")
	local calendar_content = {}

	for i = 0, months_to_show - 1 do
		local current_month = (start_month + i - 1) % 12 + 1
		local current_year = start_year + math.floor((start_month + i - 1) / 12)
		local month_calendar = create_month_calendar(current_month, current_year)
		vim.list_extend(calendar_content, month_calendar)
		table.insert(calendar_content, "") -- Add an empty line between months
	end

	api.nvim_buf_set_lines(buffer, 0, -1, false, calendar_content)

	-- Split the window on the left and open the calendar buffer
	api.nvim_command("leftabove vsplit")
	api.nvim_command("buffer " .. buffer)

	-- Set a variable to keep track of the starting month and year for scrolling
	api.nvim_buf_set_var(buffer, "calendar_start_month", start_month)
	api.nvim_buf_set_var(buffer, "calendar_start_year", start_year)
	api.nvim_buf_set_var(buffer, "calendar_months_to_show", months_to_show)

	-- Set key mappings for scrolling
	api.nvim_buf_set_keymap(
		buffer,
		"n",
		"j",
		":lua require('nvim-calendar.get-events').next_month()<CR>",
		{ noremap = true, silent = true }
	)
	api.nvim_buf_set_keymap(
		buffer,
		"n",
		"k",
		":lua require('nvim-calendar.get-events').prev_month()<CR>",
		{ noremap = true, silent = true }
	)

	-- Set up click mappings dynamically every time the calendar is displayed or refreshed
	setup_day_click_mappings(buffer, start_month, start_year)
end

-- Function to show the calendar
local function show_calendar()
	local current_time = os.date("*t")
	local month = current_time.month
	local year = current_time.year

	-- Display three months starting from the current month
	display_calendar(month, year, 3)
end

-- Function to go to the next month
local function next_month()
	local buf = api.nvim_get_current_buf()
	local start_month = api.nvim_buf_get_var(buf, "calendar_start_month")
	local start_year = api.nvim_buf_get_var(buf, "calendar_start_year")
	local months_to_show = api.nvim_buf_get_var(buf, "calendar_months_to_show")

	local new_month = start_month + 1
	local new_year = start_year
	if new_month > 12 then
		new_month = 1
		new_year = start_year + 1
	end

	display_calendar(new_month, new_year, months_to_show)
end

-- Function to go to the previous month
local function prev_month()
	local buf = api.nvim_get_current_buf()
	local start_month = api.nvim_buf_get_var(buf, "calendar_start_month")
	local start_year = api.nvim_buf_get_var(buf, "calendar_start_year")
	local months_to_show = api.nvim_buf_get_var(buf, "calendar_months_to_show")

	local new_month = start_month - 1
	local new_year = start_year
	if new_month < 1 then
		new_month = 12
		new_year = start_year - 1
	end

	display_calendar(new_month, new_year, months_to_show)
end

-- Function to execute a Python script and capture the output
local function execute_python(script_path, day)
	local command = string.format("python3 %s '%s'", script_path, day)
	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	return result
end

-- Function to display events in a buffer
local function display_events(events)
	local event_buffer = api.nvim_create_buf(false, true)
	local event_lines = {}

	-- Check if there are no events
	if events == "" or events == nil then
		table.insert(event_lines, "No events for this day.")
	else
		-- Split the events output into separate lines
		for line in events:gmatch("[^\r\n]+") do
			table.insert(event_lines, line)
		end
	end

	api.nvim_buf_set_lines(event_buffer, 0, -1, false, event_lines)
	api.nvim_command("rightbelow vsplit")
	api.nvim_command("buffer " .. event_buffer)
end

-- Function to handle clicking on a day
local function on_day_click()
	local buf = api.nvim_get_current_buf()
	local cursor_pos = api.nvim_win_get_cursor(0)
	local line = cursor_pos[1] - 1
	local col = cursor_pos[2]

	-- Get the line content
	local line_content = api.nvim_buf_get_lines(buf, line, line + 1, false)[1]
	local days = {}

	-- Capture all days in the line
	for day in line_content:gmatch("%d+") do
		table.insert(days, tonumber(day))
	end

	-- Find the correct day based on the cursor position
	local selected_day = nil
	local position = 0

	for _, day in ipairs(days) do
		-- Calculate the start position of the day in the line
		local day_str = string.format("%2d ", day) -- Format the day to two digits
		position = position + #day_str

		-- If the cursor position is within the bounds of the current day string
		if col < position then
			selected_day = day
			break
		end
	end

	if selected_day then
		-- Calculate the month and year based on the current line
		local start_month = api.nvim_buf_get_var(buf, "calendar_start_month")
		local start_year = api.nvim_buf_get_var(buf, "calendar_start_year")

		-- Determine the current month from the calendar header
		local current_month_index = math.floor(line / 8) -- Each month takes up a few lines, adjust as necessary
		local current_month = (start_month + current_month_index - 1) % 12 + 1
		local current_year = start_year + math.floor((start_month + current_month_index - 1) / 12)

		-- Debugging print statement to check day selection
		print(string.format("Selected day: %d, Month: %d, Year: %d", selected_day, current_month, current_year))

		-- Convert clicked date to a format compatible with the Python script
		local clicked_date = string.format("%04d-%02d-%02d", current_year, current_month, selected_day)

		-- Get the path to the Python script
		local plugin_dir = vim.fn.stdpath("data") .. "/lazy/nvim-calendar"
		local python_script_path = plugin_dir .. "/scripts/get_events.py"

		-- Execute the Python script and get events
		local events = execute_python(python_script_path, clicked_date)

		-- Display the events in a new buffer
		display_events(events)
	else
		print("No valid day selected.")
	end
end
local calendar_module = {
	next_month = next_month,
	prev_month = prev_month,
	on_day_click = on_day_click,
	show_calendar = show_calendar,
}

-- Create the Calendar command
vim.api.nvim_create_user_command("ShowCalendar", function()
	calendar_module.show_calendar()
end, { nargs = 0 })

return calendar_module
