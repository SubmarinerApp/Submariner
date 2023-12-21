# Submariner

Submariner is a Subsonic client for Mac. Originally developed by Rafaël Warnault, it was no longer maintained, and in 2012, he released it under a 3-clause BSD license.

As of 2022, I (Calvin Buckley) am fixing it up for modern macOS and Subsonic implementations. The goal is fix issues regarding compatibility, fix old bugs, add new features, modernize the application, and see what direction it should be taken in with Rafaël.

Please see the [old README](https://github.com/Read-Write/Submariner/blob/a1a10eb131eda3a073dab69423065464e9fab3ac/README.md) for past details.

## Requirements

* Submariner requires macOS 12 or newer. It works on both Intel and Apple Silicon machines.
  * The last supported version for macOS 11 is 2.4.2.
* Your Subsonic server must implement API version 1.15.0 or newer. Non-Subsonic implementations are supported.

## Building

1. Clone recursively (i.e. `git clone --recursive`). Failing that, initialize submodules recursively (`git submodule update --init --recursive`).
2. Create `Submariner/DEVELOPMENT_TEAM.xcconfig` with contents like `DEVELOPMENT_TEAM = AAAAAAAAAA`, substituting that string with your development ID. If you don't, you'll have a bad day setting up signing.
3. Use Xcode or `xcbuild` to build.

It is recommended you do `git config core.hooksPath .githooks` to avoid commiting your developer ID.
Doing so isn't fatal (it's not a secret), but it is annoying for other contributors.

## Third-Party

### Vendored

* MGScopeBar by Matt Gemmell
* PXSourceList by Alex Rozanski, Stefan Vogt
* ColumnSplitView by Matt Gallagher

## Release Notes:

### Version 3.0 (not yet released)

* macOS 12 is now the minimum version. macOS 13 or newer is recommended.
* The internal database now stores actual artist and album instead of directory IDs, alleviating many UI quirks when using Subsonic servers
  * Users of alternative server implementations like Navidrome won't notice anything, as they already use fake directory IDs based on artist and album IDs.
  * I've tried hard to make this transition as smooth as possible. Please file an issue if anything goes wrong.
  * If reloading and switching away from and back to the server doesn't help, delete recreate your server in the database.
* HTTP requests have been made more async, and shouldn't block the UI.
  * This comes with a major internal simplification to how requests are built, to be more idiomatic Swift.
* Podcasts have been made less buggy
* Adds an inspector sidebar for looking at track properties, now in default toolbar items.
  * This shows the selection, and the current playing track otherwise.
  * This is now the home of album art; clicking the image will show the full resolution in Quick Look.
* The tracklist now shows the length of the tracklist and count.
* The tracklist toolbar button will show the tracklist if you leave the cursor over the button.
* Adds an option to purge the locally downloaded/cached files. Imported files are unaffected.
* Makes the internal tracklist model index based. Duplicate tracks no longer cause UI wonkiness.
* Reduce the frequency in which the position slider is updated, reducing CPU usage
* Don't update the position slider if the window isn't visible, reducing CPU usage
* Avoid downloading tracks if they're already downloaded
* Remove some images, reduce application size
* Don't show 404 messages to avoid noise w/ ID migrations
* Avoid hitting download endpoint if unneeded
* HTTP timeouts are now handled correctly
* Use remote album artist name when importing downloaded tracks
* Fix tracks unable to be downloaded from Subsonic servers
* Fix a crash when trying to play an album without any tracks
* Fix a crash if the track's duration is nil
* Fix attribute names in schema blocking future refactors.

### Version 2.4.2

* Fixes crash importing items into local library

### Version 2.4.1

* Items in a playlist can be shown in the library
* Restore old values when cancelling editing a server
* Validate URL before saving a server's settings
* If the database is corrupted when trying to exit, don't get stuck in a loop
* Handle nil URLs without crashing
* Update item dependencies (i.e. track to album) when fetching from server
* Fix not updating indices when connecting to a server
* Fix accidental mix-up of tag and index based IDs
* Don't display artists with a nil ID

### Version 2.4

* Server library scans can be kicked off from the UI
* Multiple items can be removed from a playlist at once
* Non-existent server items are automatically removed
* Better support for servers that don't support some features (i.e. now playing)
* Server playlists can be renamed
* Fix an infinite loop when leaving search results
* Fix an infinite loop with server now playing
* Fix crash with shuffle
* Fix crashes with null hostnames
* Fix issue with column headers in server search and playlists
* Fix reordering server playlists
* Fix issue with playlist items not pointing to known items not having metadata
* Appending to or removing items from server playlists is more efficient
* Rewrite Subsonic response parsing in Swift

### Version 2.3.1

* Only try precise times for FLACs which need it, and not other file types
* When enabled, only download a track before its start.
* Always scrobble, even if using a remote stream, to workaround Navidrome behaviour
* Fix not connecting to the server if a playlist is the first thing opened
* Fix crash with empty username or password
* Fix issues with empty artist or album names
* Improve error logging on the console, using structured logging
* Rewrite SBAppDelegate in Swift

### Version 2.3

* The current right sidebar view is remembered for next launch
* The volume button shows the popover when scrolled on, to show current volume
* The repeat and shuffle toolbar buttons now show toggle state
* Fix repeat and shuffle options not being respected by player
* Fix server name being empty causing problems
* Fix now playing information not being set properly with nil attributes
* Fix authentication callback being called twice
* The playback notification is rescinded upon playback stopping or quitting
* Added "Show in Library" to the menu bar
* Show API endpoint that caused a non-successful HTTP response
* Clean up moving tracks in the tracklist
* Clean up playlist and track fetch code when parsing responses
* Avoid making junk cover objects for tracks
* Clean up password caching
* Rewrite SBOnboardingController in SwiftUI
* Rewrite SBPlayer in Swift
* Rewrite SBClientController in Swift, improving performance

### Version 2.2

* Rewrite many components in Swift
* The now playing view now shows the last update and can show the track in the library
* The tracklist and server users toolbar items show toggle state
* Fix issue with Keychain passwords not getting set correctly
* Fix issue with the system now playing control metadata not being updated correctly
* Fix issue with download operations not copying files
* Fix issue where cached files weren't being used
* Fix issue with automatic caching not being reliable
* Fix issue with download operations spuriously cancelling themselves
* Fix issue with context menus not properly using the focused control

### Version 2.1.1

* Fix server playlists being loaded out of order
* Fix the spacebar not toggling pause if the album selection was focused
* Optimize performance with album listing
* Fix seeking in FLAC files
* Revise onboarding window (fix resizing, show more consistently)

### Version 2.1

* Updated icon
* Basic AirPlay support
* Spacebar now toggles playback
* Number of tracks and length is shown
* Token authentication can now be toggled
* Onboarding is now inline with the window
* Improvements for macOS 13
  * Settings instead of Preferences when on macOS 13
  * Variable SF Symbols for the toolbar volume icon
* Notifications are now interactable
  * Skip button, default action shows current track in database window
* Option to delete track from tracklist after finishing
* Can navigate back and forth between views with NSPageController
  * Trackpad navigation gestures are supported
* Tracklist button is a drop target for library items
* Table columns can now be hidden
* Tweaks to split view, to try remember state better
* Fixes sort order
* Clean up path handling
* Slowly rewriting things in Swift

### Version 2.0

* Now requires macOS 11.x
* Overhauled UI to fit modern macOS design and UI conventionsa
  * Basic dark mode support
  * SF Symbols for UI elements
  * Tracklist and now playing view moved to sidebar
  * Expanded menu bar
  * Onboarding dialog for new users
* Uses App Sandboxing
* Uses Keychain to store passwords
* Stores relative paths in database instead of absolute, for easier portability
* Local library imports properly set covers
* Remembers last opened view
* Updates tracks from server
* Uses disc numbers for sorting
* Uses AVFoundation instead of QuickTime and SFBAudioEngine for playback
* Uses Audio Toolbox and AVFoundation for metadata instead of SFBAudioEngine
* Notifications for currently playing track
* Use MPNowPlayingInformationCenter instead instead of a menu applet and hooking system media keys
* Now uses built-in NSURLSession instead of library for HTTP connections
* Uses NSPopover instead of MAAttachedWindow
* Informs the local server about playing cached tracks
* Uses Subsonic token auth
* Refactored to use ARC instead of GC

### Version 1.1:

* Add Lossless support for local player.
* Add Mini-Player Menu, callable via a customizable hot-key shortcut.
* Add Max Cover Size setting.
* Add zoom setting for album browser views.
* Improve authentication by supporting password encoding.
* Improve global design, navigation and frame persistence.
* Improve player progress bar stability and design.
* Improve Track-list design.
* Improve cache-streaming engine stability.
* Improve general speed, around 20% faster.
* Fix bug in "Import Audio Files" feature when "Link" option is chosen.
* Fix special character bug in server password.
* Fix memory leaks around REST API

### Version 1.0:

* Initial release.
