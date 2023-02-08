# Submariner

Submariner is a Subsonic client for Mac. Originally developed by Rafaël Warnault, it was no longer maintained, and in 2012, he released it under a 3-clause BSD license.

As of 2022, I (Calvin Buckley) am fixing it up for modern macOS and Subsonic implementations. The goal is fix issues regarding compatibility, fix old bugs, add new features, modernize the application, and see what direction it should be taken in with Rafaël.

Please see the [old README](https://github.com/Read-Write/Submariner/blob/a1a10eb131eda3a073dab69423065464e9fab3ac/README.md) for past details.

## Building

1. Clone recursively (i.e. `git clone --recursive`). Failing that, initialize submodules recursively (`git submodule update --init --recursive`).

2. Use Xcode or `xcbuild` to build.

It is recommended you do `git config core.hooksPath .githooks` to avoid commiting your developer ID.
Doing so isn't fatal (it's not a secret), but it is annoying for other contributors.

## Third-Party

### Vendored

* MGScopeBar by Matt Gemmell
* PXSourceList by Alex Rozanski, Stefan Vogt
* ColumnSplitView by Matt Gallagher

## Release Notes:

### Version 2.1 (not yet released)

* Basic AirPlay support
* Spacebar now toggles playback
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
* Tweaks to split view, to try remember state better
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
