class_name GameProgress
extends RefCounted
## Remembers whether the player has finished the game (reached the credits) - for this session only.
## It lives in memory, not in a save file: refreshing the browser page (or relaunching the game)
## starts again from the first-visit main menu (leafy tree, first music).

static var _finished := false


static func has_finished() -> bool:
	return _finished


static func mark_finished() -> void:
	_finished = true


static func reset() -> void:
	_finished = false
