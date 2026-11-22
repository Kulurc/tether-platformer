class_name GameProgress
extends RefCounted
## Remembers whether the player has finished the game (reached the credits), across sessions.
## Saved in the player's user data: user://progress.cfg on desktop, browser storage on the web.
## To test the first-time menu again: delete that file (Project -> Open User Data Folder), or in a
## browser clear the site's data. Or call GameProgress.reset() from a script.

const PATH := "user://progress.cfg"


static func has_finished() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	return bool(cfg.get_value("progress", "finished", false))


static func mark_finished() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # keep anything else already saved
	cfg.set_value("progress", "finished", true)
	cfg.save(PATH)


static func reset() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("progress", "finished", false)
	cfg.save(PATH)
