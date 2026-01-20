# mk - Marked Command Line Tool

`mk` is a command-line utility for interacting with
[Marked][1] via its URL scheme handler. It allows you to
open files, stream content from STDIN, refresh previews,
manage styles, run JavaScript commands, and control various
Marked features directly from the terminal.

## Features

* __Open Markdown files__ in Marked from the command line
* __Stream content from STDIN__ to Marked's Streaming
  Preview
* __Refresh preview windows__ (specific file, all windows,
  or frontmost)
* __Manage Marked preferences__ and settings
* __Add custom CSS styles__ to Marked
* __Run JavaScript commands__ in preview windows
* __Control Marked features__ like Style Stealer, Content
  Extractor, Markdown Dingus, and more

## Installation

### Building from Source

#### Prerequisites

* macOS (10.13 or later)
* Xcode (latest version recommended)
* Swift toolchain

#### Build Steps

1. __Open the project in Xcode:__

   ```bash
   cd marked/mk
   open mk.xcodeproj
   ```
1. __Build the project:__
	- In Xcode: Product → Build (⌘B)
	- Or from command line:

     ```bash
     xcodebuild -project mk.xcodeproj -scheme mk -configuration Release
     ```
1. __Find the built binary:__
	- In Xcode: Products → mk (right-click → Show in Finder)
	- Command line build: `build/Release/mk` (or check Xcode's
   Derived Data folder)
2. __Install the binary__ (optional):

   ```bash
   # Copy to a directory in your PATH
   cp mk /usr/local/bin/mk
   # Or install to /opt/homebrew/bin/ if using Homebrew on Apple Silicon
   cp mk /opt/homebrew/bin/mk
   ```

   Make sure the binary is executable:

   ```bash
   chmod +x /usr/local/bin/mk
   ```

## Usage

### Basic Usage

```bash
# Open a markdown file in Marked
mk file.md

# Stream content from STDIN to Streaming Preview
echo "# Hello World" | mk

# Explicitly use STDIN
mk -
```

### Command Options

#### File Operations

* __`mk [file]`__ - Open a markdown file in Marked
* __`mk [file] --raise`__ - Open file and raise the window
  above all others

#### STDIN and Streaming

* __`mk`__ or __`mk -`__ - Read from STDIN and open
  Streaming Preview
* __`mk --stream`__ - Open Streaming Preview window without
  reading STDIN

#### Preview Management

* __`mk --refresh`__ - Refresh the frontmost preview window
* __`mk --refresh all`__ - Refresh all open preview windows
* __`mk --refresh file.md`__ - Refresh the preview for a
  specific file

#### Preferences

* __`mk --pref`__ - Open Marked preferences (General page)
* __`mk --pref Advanced`__ - Open preferences to a specific
  page
* __`mk --defaults KEY=VALUE [KEY=VALUE...]`__ - Set user
  preferences

  ```bash
  mk --defaults syntaxHighlight=1 includeMathJax=0 processor=multimarkdown
  ```

#### Style Management

* __`mk --style NAME`__ - Set preview style for open windows
* __`mk --add-style FILE`__ - Add a CSS file as a custom
  style to Marked

  ```bash
  mk --add-style ~/Styles/custom.css
  ```

#### JavaScript Execution

* __`mk --dojs "JAVASCRIPT_COMMAND"`__ - Run JavaScript in
  frontmost window
* __`mk --dojs "SCRIPT" all`__ - Run JavaScript in all
  windows
* __`mk --dojs "SCRIPT" file.md`__ - Run JavaScript in
  specific file(s)

  ```bash
  mk --dojs "window.scrollTo(0,0)"
  mk --dojs "alert('Hello')" all
  ```

#### Content Extraction and Import

* __`mk --extract URL`__ - Extract content from URL and open
  in Marked

  ```bash
  mk --extract https://example.com/article
  ```
* __`mk --importurl [URL]`__ - Open Import URL window
  (optionally with URL)
* __`mk --stylestealer [URL]`__ - Open Style Stealer HUD
  (optionally with URL)

#### Utility Commands

* __`mk --paste`__ - Create new document from clipboard
* __`mk --preview TEXT`__ - Preview text directly in a new
  document
* __`mk --dingus`__ - Open Markdown Dingus for testing
  processors
* __`mk --help`__ or __`mk -h`__ - Show usage information

### Examples

```bash
# Open a file
mk document.md

# Open with window raise
mk document.md --raise

# Stream markdown from a file
cat notes.md | mk

# Stream and process
grep -i "important" notes.md | mk

# Refresh all previews
mk --refresh all

# Add a custom style
mk --add-style ~/Documents/MyTheme.css

# Set preferences
mk --defaults syntaxHighlight=1 processor=multimarkdown

# Run JavaScript to scroll to top in all windows
mk --dojs "window.scrollTo(0,0)" all

# Extract content from a webpage
mk --extract https://blog.example.com/article

# Preview some text directly
mk --preview "## Hello\n\nThis is **markdown** text!"
```

## How It Works

`mk` uses Marked's URL scheme handler (`x-marked-3://`) to
communicate with the application. When you run a command,
`mk` :

1. Parses command-line arguments
2. Validates file paths (if provided)
3. Constructs the appropriate `x-marked-3://` URL
4. Opens the URL using macOS's `NSWorkspace` , which
   launches Marked or sends the command to an
   already-running instance

For STDIN streaming, `mk`:

1. Reads all data from standard input
2. Writes it to a named pasteboard (`mkStreamingPreview`)
3. Opens the Streaming Preview window in Marked
4. Marked then reads from the pasteboard and displays the
   content

## Error Handling

The tool provides helpful error messages for common issues:

* __File not found__: When a specified file doesn't exist
* __Invalid arguments__: When command syntax is incorrect
* __STDIN errors__: When input cannot be read or decoded

Exit codes:

* `0` - Success
* `1` - Error (file not found, invalid input, etc.)

## Integration

### Shell Aliases

Add to your `~/.zshrc` or `~/.bash_profile`:

```bash
alias mko='mk --raise'  # Open with raise
alias mkr='mk --refresh all'  # Refresh all
```

### Scripts

Use `mk` in shell scripts for automation:

```bash
#!/bin/bash
# Watch a file and stream changes to Marked
fswatch -o document.md | while read; do
  cat document.md | mk
done
```

### Workflows

Combine with other tools:

```bash
# Convert clipboard to markdown and preview
pbpaste | markdown | mk

# Search and preview
grep -r "TODO" . | head -20 | mk
```

## Requirements

* __Marked 3__ or later must be installed
* macOS 10.13 (High Sierra) or later
* Marked must be running or available in Applications

## Limitations

* File paths must be accessible to Marked
* STDIN streaming requires Marked to be running
* Some commands require Marked to be active/running
* JavaScript execution only works on open document windows

## Troubleshooting

__Command not found:__

* Ensure `mk` is in your PATH
* Check that the binary is executable: `chmod +x mk`

__Marked doesn't open:__

* Verify Marked is installed in `/Applications`
* Check that Marked can handle `x-marked-3://` URLs
* Try opening Marked manually first

__STDIN not working:__

* Ensure Marked is running
* Check that Streaming Preview feature is available in your
  Marked version
* Try the `--stream` flag separately

__File not opening:__

* Verify the file path is correct and accessible
* Check file permissions
* Ensure the file has a `.md` extension (or is recognized by
  Marked)

## License

Part of the Marked application. See the main Marked project
for license information.

## Support

For issues, feature requests, or questions:

* Check the main [Marked documentation][1]
* Review the URL Handler documentation in Marked's help
* Contact Marked support

## Contributing

This utility is part of the Marked project. Contributions
should follow the main project's contribution guidelines.

[1]: https://markedapp.com

