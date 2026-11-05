extends RefCounted
## Storage seam. Game talks ONLY to this interface, never to FileAccess directly.
## Today: local JSON (atomic write + backup). Later: a RemoteSaveStore (HTTP/cloud save) with the
## same two methods, or a hybrid that syncs the local copy. No game logic lives here.
const PATH := "user://save.json"
const TMP := "user://save.tmp"
const BAK := "user://save.bak"

## Returns the saved state dictionary, or {} if none/corrupt.
func load_state() -> Dictionary:
	for path in [PATH, BAK]:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("fams") and parsed.has("brigade"):
			return parsed
	return {}

func save_state(state: Dictionary) -> bool:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		push_error("cannot write save")
		return false
	f.store_string(JSON.stringify(state))
	f.close()
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(PATH, BAK)
	DirAccess.rename_absolute(TMP, PATH)
	return true
