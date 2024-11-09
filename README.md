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

- Use command `:Showevents` to bring up a calendar ui. Select a date from the calendar to view the events on that day
  


---

## Development
```[tasklist]
- [~] Events are now written to telescope ~create a full UI calendar in nvim written in lua (in progress)~
- [ ] https://github.com/adam-coates/nvim-calendar/issues/1
- [ ] Compatability for neovim on windows
- [x] Support for more than 1 calendar 
- [x] Create more in-depth instructions on how to obtain `credentials.json` in README.md
```

