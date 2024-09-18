## Add Calendar event to google calendar from within neovim

> Lua

```lua
return {
    'adam-coates/neovim-google-event-plugin',
    config = function()
        require('google_event_plugin')
    end
}
```

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

To interact with Google Calendar, you’ll need access to the Google Calendar API:

- Go to the Google Cloud Console.
- Create a new project.
- Enable the "Google Calendar API".
- Create credentials (OAuth 2.0 client ID) to get the client_id and client_secret for authenticating your application.
- Download the credentials in JSON format.

Store `JSON` in ~/.cache/nvim-calendar-add
