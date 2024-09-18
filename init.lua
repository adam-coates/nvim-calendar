local M = {}

function M.setup()
	-- Register the user command
	vim.api.nvim_create_user_command("AddGoogleEvent", function()
		require("google_calendar_event.event").create_google_event_ui()
	end, {})
end

return M
