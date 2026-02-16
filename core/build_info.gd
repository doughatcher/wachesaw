## Build metadata — version, git SHA, copyright.
## SHA is read from res://core/git_sha.txt (generated at build time).
extends Node

const VERSION := "0.1.0"
const COPYRIGHT := "© 2026 Doug Hatcher"

var git_sha: String = "dev"

func _ready() -> void:
	if FileAccess.file_exists("res://core/git_sha.txt"):
		var f := FileAccess.open("res://core/git_sha.txt", FileAccess.READ)
		if f:
			git_sha = f.get_as_text().strip_edges()

func get_version_string() -> String:
	return "v%s (%s)" % [VERSION, git_sha]

func get_full_info() -> String:
	return "%s  •  %s" % [COPYRIGHT, get_version_string()]
