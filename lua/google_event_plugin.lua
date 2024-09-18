local function write_event_to_yaml(file_path, event_data)
	local yaml_content = string.format(
		[[
---
event:
  summary: "%s"
  start: "%s"
  end: "%s"
  location: "%s"
  description: "%s"
  timezone: "%s"
  color: %s
---
        ]],
		event_data.summary or "",
		event_data.start or "",
		event_data["end"] or "",
		event_data.location or "",
		event_data.description or "",
		event_data.timezone or "UTC",
		event_data.color or "7"
	)

	local file = io.open(file_path, "w")
	if file then
		file:write(yaml_content)
		file:close()
	else
		print("Error: Could not open file " .. file_path)
	end
end

local function check_and_install_requirements()
	-- Check if pip is installed
	local handle = io.popen("command -v pip3")
	local pip_path = handle:read("*a")
	handle:close()

	if pip_path == "" then
		print("Error: pip3 is not installed. Please install pip3 and try again.")
		return false
	end

	local plugin_dir = vim.fn.stdpath("data") .. "/lazy/nvim-calendar-add"
	-- Path to the Python requirements.txt file
	local requirements_path = plugin_dir .. "/python/requirements.txt"

	-- Read the requirements.txt file
	local requirements_file = io.open(requirements_path, "r")
	if not requirements_file then
		print("Error: Unable to open requirements.txt.")
		return false
	end

	local missing_packages = {}
	for requirement in requirements_file:lines() do
		-- Strip any version specifier from the requirement
		local package_name = requirement:match("^[^=<>~]+")

		-- Check if the package is installed using pip freeze
		local check_handle = io.popen("pip3 freeze | grep '^" .. package_name .. "=='")
		local result = check_handle:read("*a")
		check_handle:close()

		-- If the package is not found in pip freeze, add it to the missing packages list
		if result == "" then
			table.insert(missing_packages, requirement)
		end
	end
	requirements_file:close()

	if #missing_packages == 0 then
		return true
	else
		-- If there are missing packages, install them
		print("Installing missing Python dependencies...")
		for _, requirement in ipairs(missing_packages) do
			vim.cmd("!pip3 install " .. requirement)
		end
		return true
	end
end
local function create_google_event_ui()
	-- Ensure Python requirements are installed
	if not check_and_install_requirements() then
		return
	end

	-- Prompt the user for input
	local summary = vim.fn.input("Summary: ")
	local start_time = vim.fn.input("Start Time: ")
	local end_time = vim.fn.input("End Time: ")
	local location = vim.fn.input("Location: ", "")
	local description = vim.fn.input("Description: ", "")
	local timezone = vim.fn.input("Timezone: ", "UTC")
	local color = vim.fn.input("Color: ", "7")

	-- Ensure required fields are not empty
	if summary == "" or start_time == "" or end_time == "" then
		print("Error: Summary, Start Time, and End Time are required.")
		return
	end

	-- Create event data table
	local event_data = {
		summary = summary,
		start = start_time,
		["end"] = end_time,
		location = location,
		description = description,
		timezone = timezone,
		color = color,
	}

	-- Write event data to YAML file
	local file_path = "/tmp/neovim_google_event.yaml"
	write_event_to_yaml(file_path, event_data)

	-- Get the path to the Python script
	--local script_dir = vim.fn.expand("<sfile>:p:h:h")
	local plugin_dir = vim.fn.stdpath("data") .. "/lazy/nvim-calendar-add"
	local python_script_path = plugin_dir .. "/python/add_event.py"
	--	local python_script_path = script_dir .. "/python/add_event.py"

	-- Notify the user
	print("Event written to " .. file_path)

	-- Execute the Python script with the YAML file as an argument
	vim.cmd("!python3 " .. python_script_path .. " " .. file_path)
end

-- Create user command in Neovim to trigger the event creation UI
vim.api.nvim_create_user_command("AddGoogleEventui", function()
	create_google_event_ui()
end, {})
