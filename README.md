```
██╗     ██╗████████╗███████╗███████╗   ███╗   ██╗██╗   ██╗██╗███╗   ███╗
██║     ██║╚══██╔══╝██╔════╝██╔════╝   ████╗  ██║██║   ██║██║████╗ ████║ Lightweight
██║     ██║   ██║   █████╗  █████╗     ██╔██╗ ██║██║   ██║██║██╔████╔██║ Integrated
██║     ██║   ██║   ██╔══╝  ██╔══╝     ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║ Text
███████╗██║   ██║   ███████╗███████╗██╗██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║ Editing
╚══════╝╚═╝   ╚═╝   ╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝ Environment
====================================================================================
```

![litee screenshot](./contrib/litee-screenshot.png)

# litee-filetree

litee-filetree utilizes the [litee.nvim](https://github.com/ldelossa/litee.nvim) library to 
implement a tool analogous to VSCode's "Explorer" tool. 

This tool exposes an explorable tree of files and directories.

Unlike other Neovim plugins, renames of files are correctly handled and recursive moves
and copies are supported.

Like all `litee.nvim` backed plugins the UI will work with other `litee.nvim` plugins, 
keeping its appropriate place in a collapsible panel.

# Usage

## Get it

Plug:
```
 Plug 'ldelossa/litee.nvim'
 Plug 'ldelossa/litee-filetree.nvim'
```

## Set it

Call the setup function from anywhere you configure your plugins from.

Configuration dictionary is explained in ./doc/litee.txt (:h litee-config)

```
-- configure the litee.nvim library 
require('litee.lib').setup({})
-- configure litee-filetree.nvim
require('litee.filetree').setup({})
```

## Use it

The Filetree can be opened with the command "LTOpenFiletree".

Check out the help file for full details.
