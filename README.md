## Add Calendar event to google calendar from within neovim

*Written in lua and python.*

> Lua

```lua
return {
	"adam-coates/nvim-calendar",
	config = function()
		require("nvim-calendar")
	end,
}
```

- Use command `:AddGoogleEventui` to bring up the ui helper to add an event step-by-step

- Use command `:Showcalendar` to bring up a calendar ui. Select a date from the calendar to view the events on that day
  

## Add calendar event from a `yaml` 

- Create your own user command to make a calendar event using `yaml`

```lua
vim.api.nvim_create_user_command("AddGoogleEvent", function()
	vim.cmd("write")

	local file_path = vim.fn.expand("%:p")

	vim.cmd("!python3 ~/.local/share/nvim/lazy/nvim-calendar-add/python/add_event.py " .. file_path)
end, {})
```
### Example yaml

```yaml
---
event:
  summary: "Bobs birthday"
  start: "Tomorrow 8pm"
  end: "Tomorrow 9pm"
  location: "bobs house"
  description: "Don't forget to get him a present"
  timezone: "CET"
  color: 7
---
```
- Once the `yaml` is written carry out command `:AddGoogleEvent`

## Add time of events using natural language

e.g.

`Start Time: Tomorrow 2pm`
`End Time: Tomorrow 5pm`

OR

`Start Time: monday 2pm`
`End Time: tuesday 5pm`

Requires some python modules:

```
google-auth
google-auth-oauthlib
google-auth-httplib2
google-api-python-client
PyYAML
dateparser
```

Modules are automatically installed when first running the plugin or install them using:

`pip install -r requirements.txt`



To interact with Google Calendar, you’ll need access to the Google Calendar API:

- Go to the Google Cloud Console.
- Create a new project.
- Enable the "Google Calendar API".
- Create credentials (OAuth 2.0 client ID) to get the client_id and client_secret for authenticating your application.
- Download the credentials in JSON format.

Store `credentials.json` in `~/.cache/nvim-calendar-add`

---

## Development
- [ ] Compatability for neovim on windows
- [ ] Support for more than 1 calendar 
- [ ] Create more in-depth instructions on how to obtain `credentials.json` in README.md
- [-] create a full UI calendar in nvim written in lua
