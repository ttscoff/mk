//
//  main.swift
//  mk
//
//  Created by Brett Terpstra on 1/20/26.
//

import AppKit
import Foundation

// MARK: - Version

func getVersion() -> String {
  // First, try to get version from embedded Info.plist in binary
  // (works when built with Xcode with CREATE_INFOPLIST_SECTION_IN_BINARY = YES)
  if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
    return version
  }

  // Try to get version from Marked.app's Info.plist if mk is bundled inside Marked
  // (useful when mk is in Marked.app/Contents/Resources/)
  if let markedBundlePath = Bundle.main.bundlePath.components(separatedBy: "/Contents/Resources/")
    .first,
    let markedBundle = Bundle(path: markedBundlePath),
    let version = markedBundle.infoDictionary?["CFBundleShortVersionString"] as? String
  {
    return version
  }

  // Fallback: hardcoded version (should match MARKETING_VERSION in project.pbxproj)
  // When building from source without Xcode, this will be the version shown
  return "3.0.0"
}

let MK_VERSION = getVersion()

// MARK: - Argument Parsing

struct CommandOptions {
  var filePath: String?
  var useStdin: Bool = false
  var stream: Bool = false
  var refreshFile: String? = nil  // nil = frontmost, "all" = all windows, or file path
  var prefPage: String? = nil  // nil = not used, "" = General (default), or page name
  var dingus: Bool = false
  var help: Bool = false
  var paste: Bool = false
  var preview: String?
  var extract: String?
  var stylestealer: String?
  var importurl: String?
  var style: String?
  var addStyleFile: String?
  var defaultsPairs: [String: String] = [:]
  var dojs: String?
  var dojsFile: String? = nil  // Optional file target for --dojs
  var raise: Bool = false
  var showUsage: Bool = false
  var showVersion: Bool = false
}

func parseArguments() -> CommandOptions {
  var options = CommandOptions()
  let args = Array(CommandLine.arguments.dropFirst())

  var i = 0
  while i < args.count {
    let arg = args[i]

    switch arg {
    case "-h", "--help":
      options.showUsage = true
    case "-v", "--version":
      options.showVersion = true
    case "-s", "--stream":
      options.stream = true
    case "--refresh":
      // Check if next argument is a file path or "all"
      if i + 1 < args.count && !args[i + 1].hasPrefix("-") {
        options.refreshFile = args[i + 1]
        i += 1
      } else {
        // No argument means refresh frontmost
        options.refreshFile = ""
      }
    case "--pref":
      // Check if next argument is a page name
      if i + 1 < args.count && !args[i + 1].hasPrefix("-") {
        options.prefPage = args[i + 1]
        i += 1
      } else {
        // No argument means use default (General)
        options.prefPage = ""
      }
    case "--dingus":
      options.dingus = true
    case "--paste":
      options.paste = true
    case "--raise":
      options.raise = true
    case "--preview":
      if i + 1 < args.count {
        options.preview = args[i + 1]
        i += 1
      }
    case "--extract":
      if i + 1 < args.count {
        options.extract = args[i + 1]
        i += 1
      }
    case "--stylestealer", "--steal":
      if i + 1 < args.count && !args[i + 1].hasPrefix("-") {
        options.stylestealer = args[i + 1]
        i += 1
      } else {
        options.stylestealer = ""
      }
    case "--importurl", "--markdownify":
      if i + 1 < args.count && !args[i + 1].hasPrefix("-") {
        options.importurl = args[i + 1]
        i += 1
      } else {
        options.importurl = ""
      }
    case "--style":
      if i + 1 < args.count {
        options.style = args[i + 1]
        i += 1
      }
    case "--add-style":
      if i + 1 < args.count {
        options.addStyleFile = args[i + 1]
        i += 1
      }
    case "--defaults":
      // Parse key=value pairs, can be multiple
      while i + 1 < args.count && !args[i + 1].hasPrefix("-") {
        i += 1
        let pair = args[i]
        if let equalsIndex = pair.firstIndex(of: "=") {
          let key = String(pair[..<equalsIndex])
          let value = String(pair[pair.index(after: equalsIndex)...])
          options.defaultsPairs[key] = value
        } else {
          fputs("Warning: Invalid defaults format '\(pair)', expected KEY=VALUE\n", stderr)
        }
      }
    case "--dojs":
      if i + 1 < args.count {
        options.dojs = args[i + 1]
        i += 1
        // Check if there's an optional file argument
        if i + 1 < args.count && !args[i + 1].hasPrefix("-") {
          options.dojsFile = args[i + 1]
          i += 1
        }
      }
    case "-":
      options.useStdin = true
    default:
      // If it doesn't start with -, it's a positional argument (file path or URL)
      if !arg.hasPrefix("-") {
        if options.filePath == nil {
          options.filePath = arg
        }
      }
    }
    i += 1
  }

  return options
}

// MARK: - URL Scheme Helpers

func buildURLScheme(command: String, parameters: [String: String] = [:]) -> URL? {
  var urlString = "x-marked-3://\(command)"

  if !parameters.isEmpty {
    var queryItems: [String] = []
    for (key, value) in parameters {
      if let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        queryItems.append("\(key)=\(encodedValue)")
      }
    }
    if !queryItems.isEmpty {
      urlString += "?" + queryItems.joined(separator: "&")
    }
  }

  return URL(string: urlString)
}

func openURLScheme(_ url: URL) {
  NSWorkspace.shared.open(url)
}

// MARK: - STDIN Handling

func handleSTDIN() {
  guard let data = try? FileHandle.standardInput.readToEnd() as NSData?,
    let dataString = String(data: data as Data, encoding: .utf8)
  else {
    fputs("Error: Could not read from standard input\n", stderr)
    exit(1)
  }

  let pb = NSPasteboard(name: NSPasteboard.Name("mkStreamingPreview"))
  pb.clearContents()
  pb.setString(dataString, forType: .string)

  // Open streaming preview
  if let streamURL = buildURLScheme(command: "stream") {
    openURLScheme(streamURL)
  }
}

// MARK: - File Handling

func handleFile(_ filePath: String, raise: Bool = false) {
  let fileManager = FileManager.default

  // Resolve path (handles ~, relative paths, etc.)
  var resolvedPath = filePath
  if filePath.hasPrefix("~") {
    resolvedPath = (filePath as NSString).expandingTildeInPath
  } else if !filePath.hasPrefix("/") {
    // Relative path - make it absolute from current directory
    let currentDir = fileManager.currentDirectoryPath
    resolvedPath = (currentDir as NSString).appendingPathComponent(filePath)
  }

  // Standardize path
  resolvedPath = (resolvedPath as NSString).standardizingPath

  // Check if file exists
  if !fileManager.fileExists(atPath: resolvedPath) {
    fputs("Error: File does not exist: \(resolvedPath)\n", stderr)
    exit(1)
  }

  // Build URL with file parameter
  var parameters: [String: String] = ["file": resolvedPath]
  if raise {
    parameters["raise"] = "true"
  }

  guard let openURL = buildURLScheme(command: "open", parameters: parameters) else {
    fputs("Error: Could not build URL scheme\n", stderr)
    exit(1)
  }

  openURLScheme(openURL)
}

// MARK: - Command Handlers

func showVersion() {
  print("mk version \(MK_VERSION)")
}

func showUsage() {
  let usage = """
    Usage: mk [options] [file|-]

    Open files in Marked or stream content from STDIN.

    Arguments:
      file              Path to markdown file to open in Marked
      -                 Read from STDIN and open streaming preview (default if no file specified)

    Options:
      -h, --help        Show this help message
      -v, --version     Show version information
      -s, --stream      Open streaming preview window
      --refresh [file|all]  Refresh preview(s). With no argument, refreshes frontmost window.
                           With "all", refreshes all windows. With a file path, refreshes matching window.
      --pref [page]     Open Marked preferences. With no argument, opens to General page.
                       With a page name, opens to that specific settings page.
      --dingus          Open Markdown Dingus
      --paste           Create new document from clipboard
      --raise           Raise window after opening (use with file argument)
      --preview TEXT    Preview text directly in a new document
      --extract URL     Extract content from URL and open in Marked
      --stylestealer    Open Style Stealer HUD (optionally with URL)
      --importurl       Open Import URL window (optionally with URL)
      --style NAME      Set preview style for open windows
      --add-style FILE  Add a CSS file as a custom style to Marked
      --defaults KEY=VALUE [KEY=VALUE...]  Set user preferences (multiple pairs allowed)
      --dojs SCRIPT [FILE]  Run JavaScript command in document(s). Optional FILE
                           targets specific document(s) or "all" for all documents.

    Examples:
      mk file.md                    Open file.md in Marked
      echo "# Hello" | mk           Stream from STDIN
      mk -                          Stream from STDIN (explicit)
      mk --stream                   Open streaming preview
      mk --refresh                  Refresh all previews
      mk --pref                     Open preferences
      mk --dingus                   Open Markdown Dingus
      mk --preview "Hello **world**" Preview text directly
      mk --extract https://example.com Extract and preview URL
      mk --add-style ~/Styles/custom.css Add custom style
      mk --defaults syntaxHighlight=1 includeMathJax=0 Set preferences
      mk --dojs "window.scrollTo(0,0)" Run JavaScript in frontmost window
      mk --dojs "alert('Hello')" all Run JavaScript in all windows
    """
  print(usage)
}

// MARK: - Main

func main() {
  let options = parseArguments()

  // Show version if requested
  if options.showVersion {
    showVersion()
    exit(0)
  }

  // Show usage if requested
  if options.showUsage {
    showUsage()
    exit(0)
  }

  // Handle command-only operations (no file argument needed)
  if options.refreshFile != nil {
    var params: [String: String] = [:]

    // If refreshFile is not empty, it's either "all" or a file path
    if let refreshFile = options.refreshFile, !refreshFile.isEmpty {
      params["file"] = refreshFile
    }
    // If refreshFile is empty string, no params = refresh frontmost

    if let url = buildURLScheme(command: "refresh", parameters: params) {
      openURLScheme(url)
    }
    exit(0)
  }

  if options.prefPage != nil {
    var params: [String: String] = [:]

    // If prefPage is not empty, use it; otherwise let it default to "General" on app side
    if let prefPage = options.prefPage, !prefPage.isEmpty {
      params["page"] = prefPage
    }
    // If empty, params stays empty and app defaults to "General"

    if let url = buildURLScheme(command: "pref", parameters: params) {
      openURLScheme(url)
    }
    exit(0)
  }

  if options.dingus {
    if let url = buildURLScheme(command: "dingus") {
      openURLScheme(url)
    }
    exit(0)
  }

  if options.paste {
    if let url = buildURLScheme(command: "paste") {
      openURLScheme(url)
    }
    exit(0)
  }

  if let previewText = options.preview {
    if let url = buildURLScheme(command: "preview", parameters: ["text": previewText]) {
      openURLScheme(url)
    }
    exit(0)
  }

  if let extractURL = options.extract {
    if let url = buildURLScheme(command: "extract", parameters: ["url": extractURL]) {
      openURLScheme(url)
    }
    exit(0)
  }

  if let stylestealerURL = options.stylestealer {
    var params: [String: String] = [:]
    if !stylestealerURL.isEmpty {
      params["url"] = stylestealerURL
    }
    if let url = buildURLScheme(command: "stylestealer", parameters: params) {
      openURLScheme(url)
    }
    exit(0)
  }

  if let importurlURL = options.importurl {
    var params: [String: String] = [:]
    if !importurlURL.isEmpty {
      params["url"] = importurlURL
    }
    if let url = buildURLScheme(command: "importurl", parameters: params) {
      openURLScheme(url)
    }
    exit(0)
  }

  if let addStyleFile = options.addStyleFile {
    let fileManager = FileManager.default
    var resolvedPath = addStyleFile
    if addStyleFile.hasPrefix("~") {
      resolvedPath = (addStyleFile as NSString).expandingTildeInPath
    } else if !addStyleFile.hasPrefix("/") {
      let currentDir = fileManager.currentDirectoryPath
      resolvedPath = (currentDir as NSString).appendingPathComponent(addStyleFile)
    }
    resolvedPath = (resolvedPath as NSString).standardizingPath

    if !fileManager.fileExists(atPath: resolvedPath) {
      fputs("Error: CSS file does not exist: \(resolvedPath)\n", stderr)
      exit(1)
    }

    // Extract name from filename (without extension)
    let fileName = (resolvedPath as NSString).lastPathComponent
    let nameWithoutExt = (fileName as NSString).deletingPathExtension

    var params: [String: String] = ["file": resolvedPath]
    params["name"] = nameWithoutExt

    if let url = buildURLScheme(command: "addstyle", parameters: params) {
      openURLScheme(url)
    }
    exit(0)
  }

  if !options.defaultsPairs.isEmpty {
    if let url = buildURLScheme(command: "defaults", parameters: options.defaultsPairs) {
      openURLScheme(url)
    }
    exit(0)
  }

  if let dojsScript = options.dojs {
    var params: [String: String] = ["js": dojsScript]
    if let file = options.dojsFile {
      params["file"] = file
    }
    if let url = buildURLScheme(command: "do", parameters: params) {
      openURLScheme(url)
    }
    exit(0)
  }

  // Handle file or STDIN
  if let filePath = options.filePath {
    // File path provided
    handleFile(filePath, raise: options.raise)
  } else if options.useStdin || options.stream {
    // STDIN or explicit stream request
    if options.stream && !options.useStdin {
      // Just open stream window without reading stdin
      if let url = buildURLScheme(command: "stream") {
        openURLScheme(url)
      }
    } else {
      // Read from STDIN and open stream
      handleSTDIN()
    }
  } else {
    // Default behavior: check if stdin has data
    let stdin = FileHandle.standardInput
    // Check if stdin is a TTY (terminal) - if so, show usage
    if isatty(STDIN_FILENO) != 0 {
      showUsage()
      exit(0)
    } else {
      // Has input, use STDIN
      handleSTDIN()
    }
  }
}

main()
