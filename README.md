# Submariner

Submariner is a Subsonic client for Mac. Originally developed by Rafaël Warnault, it was no longer maintained, and in 2012, he released it under a 3-clause BSD license.

As of 2022, I (Calvin Buckley) am fixing it up for modern macOS and Subsonic implementations. The goal is fix issues regarding compatibility, fix old bugs, add new features, modernize the application, and see what direction it should be taken in with Rafaël.

Please see the [old README](https://github.com/Read-Write/Submariner/blob/a1a10eb131eda3a073dab69423065464e9fab3ac/README.md) for past details.

## Requirements

* Submariner requires macOS 12 or newer. It works on both Intel and Apple Silicon machines.
  * The last supported version for macOS 11 is 2.4.2.
* Your Subsonic server must implement API version 1.16.1 or newer. Non-Subsonic implementations are supported, with limited OpenSubsonic extension support.

## Building

1. Clone recursively (i.e. `git clone --recursive`). Failing that, initialize submodules recursively (`git submodule update --init --recursive`). We don't use submodules at the moment, but it's a good idea to in case we do later.
2. Create `Submariner/DEVELOPMENT_TEAM.xcconfig` with contents like `DEVELOPMENT_TEAM = AAAAAAAAAA`, substituting that string with your development ID. If you don't, you'll have a bad day setting up signing.
  * If you're unsure what codesigning ID to use, run `security find-identity -v -p codesigning`.
3. Use Xcode or `xcbuild` to build.

It is recommended you do `git config core.hooksPath .githooks` to avoid commiting your developer ID.
Doing so isn't fatal (it's not a secret), but it is annoying for other contributors, as Git/Xcode will want you to commit changes to your developer ID, overriding what's in the repository.

## Third-Party Dependencies

### Vendored

* MGScopeBar by Matt Gemmell
* PXSourceList by Alex Rozanski, Stefan Vogt

## Release Notes

## Not yet released

* Infinite scrolling is added to search results and server albums.
  * This enables pulling results beyond the first page of results.
* All tracks on the server can be shown in a new view.
  * This can be accessed by Go - By Tracks (Cmd+3).
* Fix album information not getting pulled in from tracks on search.
* Use updated Core Data features for automatic merging of changes between threads.
  * This should reduce weirdness such as faults appearing where they shouldn't.
* Refactor cover handling to avoid cross-linked files and avoid writing on reads.
* Avoid fetching covers in some contexts to avoid slow downloads.
* Remove more dead data that can't be used in the database.
* Report progress for slow running operations.

### Version 3.3.1

* Fix getting an error message about OpenSubsonic extensions on non-OpenSubsonic servers.
* Fix a regression with the ATS plist entries that blocked non-HTTPS servers.
* Handle HTTP 410 and 501 from servers for unimplemented features.

### Version 3.3

* Basic support for displaying related tracks. This reuses the search infrastructure. The server may call external servers if configured to do so.
    * Top tracks for an artist can now be displayed
    * Similar tracks for an artist (sometimes called "radio") can now be displayed
* Directories can be starred.
* Recover from situations where the cover file was deleted from the filesystem.
* Searches can be performed from the playlist view.
* Server playlists can be created from the playlist view.
* Allow multiple items to be selected in searches.
* HTTP POST is used when the server supports it, using OpenSubsonic extensions.
* Fix the inspector alternating between modes when moving between playlist tracks.
* Fix covers being deleted by the system on macOS 15.
* Fix searches being ran twice.
* Fix albums with the same ID across multiple servers being mixed.
* Fix the initial server not refreshing on application launch.

### Version 3.2.1

* Fix the demo server disappearing on restart.
* Fix the onboarding window not showing buttons on macOS 12.
* Fix a crash with the album list on macOS 12.

### Version 3.2

* Inspector window has been improved
  * You can now switch between now playing and current selection with a tab view.
  * Playlist information can be viewed and edited.
* The playlist model has been corrected to handle multiple of the same track. (GH-192)
* Added a command to play the first disc from an album. (GH-211)
* Lower case artist names are properly sorted in the artist list.
* Favouriting items is available from the menu bar, or Cmd+E.
* Adding items to the tracklist now has a shortcut of Cmd+D.
* You can seek to a specific timestamp. (GH-84)
* You can now adjust the speed of playback. (GH-83)
* Fix parsing fractional dates returned by some servers.
* Fix the null cover being used for system now playing information.
* Upgrading from Submariner 1.x is no longer supported.

### Version 3.1.1

* Fix an issue with notification actions not working correctly.
* Fix an issue where a duplicate window was opened when clicking a notification.
* Fix an issue with database fetch code causing a crash when no items were returned.

### Version 3.1 for Workgroups

* Artists, albums, and tracks can be favourited ("starred" in Subsonic parlance; we use a heart to avoid being confused with ratings).
  * Favourited albums can be recalled in the server albums view.
  * Favourited status is synchronized to the server.
* Linking artists has been deprecated for now, and hidden behind an manual option.
  * It requires a lot more work to work correctly with arbitrary directores together with  App Sandbox.
  * To re-enable it (for now, knowing the issues), run `defaults write fr.read-write.Submariner canLinkImport -bool YES`.
  * See the discussion thread on https://github.com/SubmarinerApp/Submariner/discussions/201 for possible plans.
* A directory view has been added, for users of servers that organize files by directory and prefer managing files that way.
* A basic AppleScript dictionary has been added as a way to inspect and control playback programatically.
* Albums can be dragged tracklist or playlist drop targets to add their containing tracks.
* Files can be dropped onto the dock icon to import them.
* Empty artists entries are deleted from the local library on deleting downloaded items.
* The album sort order is configurable. By default, it sorts from oldest to newest.
* Move request handling into an off-thread queue.
* The album selection view has been rewritten to avoid deprecated types.
* Drag and drop handling code has been rewritten to avoid deprecated methods.
* Fix track ratings not getting updated from the remote server.
* Fix tracks not having a cover when imported.
* Fix imported tracks having the wrong bitrate shown in the inspector.
* Fix imported tracks not having a content type.
* Fix playlists not getting selected when navigating through history.

### Version 3.0

* macOS 12 is now the minimum version. macOS 13 or newer is recommended.
* The internal database now stores actual artist and album instead of directory IDs, alleviating many UI quirks when using Subsonic servers. (GH-73)
  * Users of alternative server implementations like Navidrome won't notice anything, as they already use fake directory IDs based on artist and album IDs.
  * I've tried hard to make this transition as smooth as possible. Please file an issue if anything goes wrong.
  * If reloading and switching away from and back to the server doesn't help, delete recreate your server in the database.
* HTTP requests have been made more async, and shouldn't block the UI. (GH-175)
  * This comes with a major internal simplification to how requests are built, to be more idiomatic Swift.
* Adds an inspector sidebar for looking at track properties, now in default toolbar items. (GH-72)
  * This shows the selection, and the current playing track otherwise.
  * This is now the home of album art; clicking the image will show the full resolution in Quick Look.
* The tracklist now shows the length of the tracklist and count. (GH-112)
* The tracklist toolbar button will show the tracklist if you leave the cursor over the button.
* Adds an option to purge the locally downloaded/cached files. Imported files are unaffected.
* Makes the internal tracklist model index based. Duplicate tracks no longer cause UI wonkiness.
* Reduce the frequency in which the position slider is updated, reducing CPU usage. (GH-169)
* Don't update the position slider if the window isn't visible, reducing CPU usage. (GH-171)
* Podcast episodes shouldn't duplicate when refreshing.
* Avoid downloading tracks if they're already downloaded.
* Remove some images from the app bundle to reduce application size.
* Use newer split view functionality available in modern macOS.
* Don't show 404 messages to avoid noise w/ database ID migrations.
* HTTP timeouts are now handled correctly, to better handle newer versions of Navidrome. (GH-174)
* Use remote album artist name when importing downloaded tracks.
* Fix tracks unable to be downloaded from Subsonic servers.
* Fix a crash when trying to play an album without any tracks. (GH-166)
* Fix a crash if the track's duration is nil.
* Fix attribute names in schema blocking future refactors. (GH-167)

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
