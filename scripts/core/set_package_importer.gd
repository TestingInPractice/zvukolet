class_name SetPackageImporter
extends RefCounted
## Импорт .zvset в пользовательские наборы.
##
## Импорт всегда создаёт новый набор. Ошибка на любом шаге удаляет набор и
## записанные файлы, поэтому неудачный импорт не оставляет мусора.

## Импорт из байтов, полученных диалогом выбора файла.
static func import_bytes(package_bytes: PackedByteArray) -> Dictionary:
	var size_error := SetPackageFormat.check_package_size(package_bytes.size())
	if not size_error.is_empty():
		return _failure(size_error)
	var temp := SetPackageArchive.read_bytes_to_temp(package_bytes)
	if not bool(temp.get("ok", false)):
		return _failure(str(temp.get("error", "bad_archive")))
	var temp_path := str(temp.get("path", ""))
	var result := import_path(temp_path)
	SetPackageArchive.cleanup_temp(temp_path)
	return result


## Импорт из пути. Используется тестами и импортом из байтов.
static func import_path(package_path: String) -> Dictionary:
	var probe := FileAccess.open(package_path, FileAccess.READ)
	if probe == null:
		return _failure("read_failed")
	var package_size := probe.get_length()
	probe.close()
	var size_error := SetPackageFormat.check_package_size(package_size)
	if not size_error.is_empty():
		return _failure(size_error)
	var archive := SetPackageArchive.read_package(package_path)
	if not bool(archive.get("ok", false)):
		return _failure(str(archive.get("error", "bad_archive")))
	var validated := SetPackageFormat.validate_manifest(
			archive.get("manifest", null), archive.get("files", {}) as Dictionary)
	if not bool(validated.get("ok", false)):
		return _failure(str(validated.get("error", "bad_manifest")))
	var manifest: Dictionary = validated.get("manifest", {}) as Dictionary
	var files: Dictionary = archive.get("files", {}) as Dictionary
	var record := CustomSetsStore.create_set(
			str(manifest.get("name", "")),
			str(manifest.get("contrast_id", "")))
	if record.is_empty():
		return _failure("create_failed")
	var set_id := str(record.get("id", ""))
	var stored := {}
	var written_paths: Array[String] = []
	for raw_entry: Variant in manifest.get("pairs", []):
		var source: Dictionary = raw_entry as Dictionary
		var pair_id := str(source.get("id", ""))
		var target_entry := {
			"word_a": str(source.get("word_a", "")),
			"word_b": str(source.get("word_b", "")),
			"image_a": "",
			"image_b": "",
			"audio_a": "",
			"audio_b": "",
		}
		for key: String in SetPackageFormat.MEDIA_KEYS:
			var media_rel := str(source.get(key, ""))
			if media_rel.is_empty():
				continue
			var extension := SetPackageFormat.extension_of(media_rel)
			var side := key.substr(key.length() - 1, 1)
			var target_path := CustomSetsStore.set_dir(set_id) \
					+ CustomSetsStore.pair_file_name(pair_id, side, extension)
			var bytes: PackedByteArray = files[media_rel] as PackedByteArray
			if not _write_bytes(target_path, bytes):
				_rollback(set_id, written_paths)
				return _failure("write_failed")
			written_paths.append(target_path)
			target_entry[key] = target_path
		stored[pair_id] = target_entry
	if not CustomSetsStore.set_pairs(set_id, stored):
		_rollback(set_id, written_paths)
		return _failure("write_failed")
	return {
		"ok": true,
		"error": "",
		"set_id": set_id,
		"name": str(manifest.get("name", "")),
		"pairs": stored.size(),
	}


static func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	if bytes.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


static func _rollback(set_id: String, written_paths: Array[String]) -> void:
	CustomSetsStore.delete_set(set_id)
	for path in written_paths:
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"set_id": "",
		"name": "",
		"pairs": 0,
	}
