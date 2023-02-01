# Deatharte Api
Just my personal _API-ary_ 🤠.

## What's the purpose of this?
Well, I just grown tired of piling up utility functions which may serve some other users as well; also I just do not like to copy-paste code around, and I wish to get into nvim plugin development.

Hopefully this readme _should_ serve as a quick guide to which functionalities it provides.

I'd rather keep number of **required dependencies** as low as possible, but I am not trying to reinvent the wheel; also *optional dependencies* are fine: The whole API **does not** load anything by itself on require/setup. 

## TODO
- In-vim `:help` entry
- Add tests tasks
- Add detailed annotations throughout the repository
- Add which-key integration

## Requirements
The API has dependencies, you may still ignore them
in case you are not going to use the whole package.

In case you are trying to use a module within the API without its dependencies,
an error will be raised accordingly only upon requiring given module.

Thus the following packages may be required, use your favorite package manager
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) to spawn jobs using `prochandler`.
- [rcarriga/nvim-notify](https://github.com/rcarriga/nvim-notify) to use the attached `notificator` handler, in short, a wrapper.

Also the following binaries may be required for the builtin prochandler jobs (`jobs.builtin`)
- `inotifywait` as a job which detects which files were updated, independently from the nvim instance.

Finally, the following are optional dependencies, meaning that while missing it, _some_ or _part_
of the module functionalities will be granted anyway:
- [kkharji/sqlite.lua](https://github.com/kkharji/sqlite.lua) to store `tracker` entries in a permanent, reliable file format. 
- [folke/which-key](https://github.com/folke/which-key.nvim) to provide a keymap legend over mapped keys.


## Installation
_Plug_ the configuration within your favorite package manager.

**Note**
While calling setup is _not_ a requirement, you may overwrite default behaviors.
At any time call `require('deatharte').fetch_configuration()` to retrieve configuraiton.

### e.g. Lazy.nvim
Using `lazy.nvim`:
```lua
{ "DrKGD/deatharte.api.nvim",
    lazy = true,
    dependencies = {
        -- # Persistent tracker entries
        { 'kkharji/sqlite.lua' },

        -- # Async jobs
        { 'nvim-lua/plenary.nvim' },

        -- # Notificator wrapper for notifications
        { 'rcarriga/nvim-notify' },

        -- # Which-key integration
        { 'folke/which-key.nvim' }
    },

    config = function()
        require('deatharte').setup {
            -- ... options ...
        }
    end },
```

## What NOT to expect
As the plugin name implies, this is only a collection of useful functionalities
which will be probably be re-used throughout my plugin collection.

You could argue that I could have used as a submodule instead, but let's take
full advantage of nvim package managers.

## API
'nough said, lets talk about the API itself, shall we?

### deatharte.hnd
`Handler` type wrappers.

#### deatharte.hnd.tracker
A dynamic list which keeps _track_ of given objects.
Currently supports sqlite to store its content.

```lua
local tck = require('deatharte.hnd.tracker').new('file-tracker')

-- # Add new entries
tck:add('file1.lua')
tck:add('file1.lua') -- # Duplicate entry are not taken in consideration
tck:add('file2.lua')
tck:add('file3.lua')

 -- # Check if the tracker currently has the given object
tck:has('file3.lua')

 -- # Runs the given callback if the tracker has the given object
tck:callback('file3.lua', function(file)
    print("Tracker has", file, "!")
end)

 -- # Either adds (if the tracker stills doesn't have the given entry) 
 -- or removes the object (if the tracker already has the given entry)
tck:toggle('file4.lua')

 -- # Removes the object
tck:remove('file4.lua')

-- # Clear the whole tracker list
tck:clear()
```

Personally I am using this as a facilitator to keep track of which files
should be issuing a compile job on write through `inotifywait`.

TODO: Still missing a save/load feature, coming right up!
TODO: Add a filter which prevents certain objects from being added to the tracked-list.

#### deatharte.hnd.notificator
In short: a wrapper for nvim-notify with some extra features I wished they were builtin.

Features:
- Same-group notifications are replaced, preventing a _storm_ of useless notification reporting _slighty_ different messages
- The notification window size is automatically updated to fit-to-its-content.
- Global enabler/disabler, in case you are costantly getting annoyed from notifications.
- List of conditional, scriptable callbacks `on_enter`, `on_close` and `on_update`.
- A static instance for a global use-case.
- Different notifications styles are builtin (info, warn, error, debug), which should provide enough variation.

```lua
local ntf = require('deatharte.hnd.notificator')

-- # A static-instance is included
-- Thus all of the following are available even without a custom instance
ntf('This is using the default static notificator, should have "sane" defaults')
ntf.spawn({ message = 'Nothing changed, same as before' })
ntf:spawn('Both ntf(...), ntf.spawn(...) and ntf:spawn(...) serve the same purpose, just syntactic sugar')
ntf:spawn({ message = { 'Multiline', 'Messages', 'Are allowed', 'Either as a table' }})
ntf:spawn({ message = '...Or\nas a string!'})
ntf:info('Same style as spawn, but on a different group')
ntf:warn('A warning, e.g. this function is deprecated')
ntf:error('This type of notification requires you to manually dismiss the message')
ntf:debug('Dismiss: manually; Is: a simple information')

-- # Define a custom notificator object
-- ntf.new({ ... defaults ... })
local myntf = ntf.new({ name = 'My personal notificator', plugin = 'my-plugin' })

-- # All of the non-static methods above
-- myntf({ ... })
-- myntf:spawn({ ... })
-- myntf:info({ ... })
-- myntf:error({ ... })
-- myntf:warn({ ... })
```

### deatharte.jobs
Spawn external jobs directly from within nvim, powered by `plenary.nvim`.

#### deatharte.jobs.prochandler
An hi-level wrapper for `plenary.nvim`, featuring:
- Spawning a new process with the given args.
- Killing and respawning the process (e.g. compilation).
- Automatically kill the job upon nvim exiting (via `VimLeavePre` autocmd).
- Attach multiple callbacks to the various available events (plenary builtin and custom defined)
    - `on_start` on process startup
    - `on_exit` on process exit
    - `on_kill` after the process has been killed manually (skips on_exit)
    - `on_respawn` when process gets re-started  (skips on_start and on_exit)
    - `on_stdout` new message received from the process stdout
    - `on_stderr` new message received from the process stderr
    - `on_status_update` when callbacks status gets changed
- Momentarily block all callbacks (e.g. no auto-compile on file change)

```lua
-- # Compile lualatex document from within nvim 
local lualatex = require('deatharte.jobs.prochandler').new({
    -- # Name in the notifications
    name = 'lualatex compile'

    -- # Command
    command = 'lualatex'

    -- # Document is compiled at the current folder 
    cwd = './',

    -- # Allow process even after nvim instance has expired (quit)
    persist_onexit = true,

    -- # Disable stdout, stderr
    on_stdout = { },
    on_stderr = { },

	args = { 
        "--synctex=1",
        "--shell-escape",
        "--halt-on-error",
        "--interaction=batchmode",
        "main.tex"
    }

    on_start = {
        function(_, obj) obj.notify:info('lualatex compile job started!') end
    }

    on_exit = {
        -- # Successful, no sigterm (15) was received and ecode is zero
        {   condition = function(_, ecode, signal) return ecode == 0 and signal == 0 end,
            function(_, obj) obj.notify:info('Compilation was successful!') end }

        -- # Not successful, job failed, non-zero exit code
        {   condition = function(_, ecode) return ecode ~= 0 end,
            function(_, obj) obj.notify:info('Compilation failed!') end }
    }
})

-- # Start the job
lualatex:start()

-- # Kill the job with sigterm
lualatex:kill()

-- # "Toggle" job, start if it yet to be started or kill it
-- I'd use this with pdf previewers, e.g. sioyek, okular...
lualatex:spawn_or_kill()

-- # Handle whether or not callbacks (on_start, on_exit, on_stdout, on_stderr, on_kill, on_respawn, on_status_update) 
-- will be fired upon the given event
-- Note that callbacks with bypass key will always be fired (if condition was met)
lualatex:resume_callbacks()
lualatex:block_callbacks()
lualatex:toggle_callbacks()
```

#### deatharte.jobs.prochandler.inotifywait
[inotifywait](https://linux.die.net/man/1/inotifywait), detect file changes using linux interface.
As the name implies, requires both `plenary.nvim` and inotifywait; features:
- All the aforementioned prochandler capabilities.
- Detects from a list of events such as `modify`, `create`, `delete`.
- Set a filter for the inotifywait binary to whitelist/blacklist filetypes, directories, or filenames 
```lua
-- # Detect file changes to lua files, default callback is a notification event
local luamodified = require('deatharte.jobs.builtin.inotifywait').new({
    events = { 'modify' },

    -- # Only lua files
    filter	= {
        type = 'whitelist',
        extension	= {
            'lua'
        },
    },

    on_status_update = {
        function(status, obj) obj.notify:info("luamodified is now", status and 'active' or 'inactive') end
    }
})

-- # Start the inotifywait
luamodified:start()
-- Aforementioned class methods are still avaialble (:kill, :spawn_or_kill...)
-- But probably this job is better handled by changing its callback status
```

### deatharte.util
As the name implies, the utility-suite of any project.

#### deatharte.util.pkgs
Dependencies, or as I like to call them, packages (pkgs) functionalities.
- **missingdeps** Check whether or not any dependency from the given list is missing. Acceps either a table or a list.
```lua
-- # e.g. list of dependencies to check for presence
local md = require('deatharte.util.pkgs').missingdeps
local list = md { 'awesome-library', 'another-awesome-library' }
if list then
	print('The following dependencies were not found', vim.inspect(list))
end
-- Output:
-- The following dependencies were not found { "awesome-library", "another-awesome-library" }

-- # e.g. same thing, but use a detailed callback instead
local md = require('deatharte.util.pkgs').missingdeps
local list = md {
    { 'awesome-library', from = 'noname/awesome-library.nvim'} ,
    { 'another-awesome-library', from ='noname/another-awesome-library.nvim' }
}
if list then
	local msg = { 'The following dependencies were found to be missing:' }
	for _, missing in ipairs(list or { }) do
		msg[#msg + 1] = ('   ‹%s› from ‹%s›'):format(missing[1], missing.from)
	end

	print(table.concat(msg, '\n'))
end
-- Output: 
-- The following dependencies were found to be missing:
--    ‹awesome-library› from ‹noname/awesome-library.nvim›
--    ‹another-awesome-library› from ‹noname/another-awesome-library.nvim›
```

#### deatharte.util.string
Short-lived, string related functionalities.

- **utf8len** Determines length of an utf8 string.
- **count** Determines number of occurences of the given pattern in the string.

#### deatharte.util.path
Path related functionalities, probably tons of other APIs serves similiar purposes (and way better than I do).

- **fileExists** Determines whether or not the file exists.
- **dirExists** Determines whether or not the directory exists.
- **isDir** Determines whether or not the given path is a directory or a file.
- **dirParent** Returns the parent directory of the given filename.

#### deatharte.util.vim
Wrappers around vim builtin wrappers.

**NOTE** Currently these functionalities are underdeveloped, precisely they are not user-ready, I'd avdise against using them in your configuration at any point, further updates will follow.
- **setup_keybindings** Setup keybindings using a table-like format, inspired by `legendary.nvim`.
- **setup_usercommands** Setup usercommands with a custom prefix.

## Issue tracker
If either you were to spot a bug at any point in the repository, or
you have any consideration/suggestion, do not hesistate and open an issue; I am not an experienced developer (I just do not consider myself to be one yet), I tend to read lots of documentations, but filthy bugs or faulty logic are bound to happen.

## Self-plug
Hi there, this is Deatharte, nice to see you here!
Hopefully you will also like my other plugins... which will be coming soon!
