class_name SaveIO
extends RefCounted
## Small JSON persistence helpers with atomic writes and format versioning.
##
## Writes go to "<path>.tmp" first and are then renamed over the real file, so a
## crash mid-write can't corrupt an existing save.

const VERSION_KEY := "_save_version"


static func write_json(path: String, data: Dictionary, version: int) -> Error:
	var payload := data.duplicate(true)
	payload[VERSION_KEY] = version
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("SaveIO: can't open %s (%s)" % [tmp_path, error_string(err)])
		return err
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	return dir.rename(tmp_path.get_file(), path.get_file())


## Returns an empty Dictionary if the file is missing or unreadable.
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveIO: %s is corrupt; ignoring it" % path)
		return {}
	return parsed


static func get_version(data: Dictionary) -> int:
	return int(data.get(VERSION_KEY, 0))


static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
