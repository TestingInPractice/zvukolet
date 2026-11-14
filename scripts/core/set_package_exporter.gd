class_name SetPackageExporter
extends RefCounted
## Экспорт пользовательского набора в файл .zvset.
##
## Собирает манифест и медиа, упаковывает в ZIP. Медиа, которое не удалось
## прочитать, пропускается и считается: набор без картинки лучше, чем отказ.

const EXPORT_TEMP_DIR := "user://package_exports"


## Экспорт в конкретный путь без диалогов. Для тестов и будущего UI сохранения.
static func export_to_path(set_id: String, output_path: String) -> Dictionary:
	if output_path.strip_edges().is_empty():
		return _failure("write_failed")
	var collected := _collect(set_id)
	if not bool(collected.get("ok", false)):
		return collected
	var written := SetPackageArchive.write_package(
			output_path,
			collected.get("manifest", {}) as Dictionary,
			collected.get("files", {}) as Dictionary)
	if not bool(written.get("ok", false)):
		return written
	if _file_size(output_path) > SetPackageFormat.MAX_PACKAGE_BYTES:
		SetPackageArchive.cleanup_temp(output_path)
		return _failure("too_large")
	return {
		"ok": true,
		"error": "",
		"path": output_path,
		"name": output_path.get_file(),
		"skipped": int(collected.get("skipped", 0)),
	}


## Собирает ZIP в памяти и возвращает его байты.
static func build_package_bytes(set_id: String) -> Dictionary:
	var collected := _collect(set_id)
	if not bool(collected.get("ok", false)):
		return collected
	var record := CustomSetsStore.get_set(set_id)
	var file_name := default_file_name(str(record.get("name", "")))
	var temp_path := "%s/export_%d.zvset" % [EXPORT_TEMP_DIR, Time.get_ticks_usec()]
	var written := SetPackageArchive.write_package(
			temp_path,
			collected.get("manifest", {}) as Dictionary,
			collected.get("files", {}) as Dictionary)
	if not bool(written.get("ok", false)):
		return written
	var bytes := _read_file_bytes(temp_path)
	SetPackageArchive.cleanup_temp(temp_path)
	if bytes.is_empty():
		return _failure("write_failed")
	if bytes.size() > SetPackageFormat.MAX_PACKAGE_BYTES:
		return _failure("too_large")
	return {
		"ok": true,
		"error": "",
		"bytes": bytes,
		"file_name": file_name,
		"skipped": int(collected.get("skipped", 0)),
	}


## Имя файла для сохранения. Запрещённые символы заменяются на "_".
static func default_file_name(set_name: String) -> String:
	var safe := set_name.strip_edges()
	for forbidden: String in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(forbidden, "_")
	if safe.is_empty():
		safe = "набор"
	if safe.length() > SetPackageFormat.MAX_NAME_LENGTH:
		safe = safe.substr(0, SetPackageFormat.MAX_NAME_LENGTH)
	return safe + "." + SetPackageFormat.EXTENSION


## Собирает манифест и файлы набора. Пропущенное медиа считается.
static func _collect(set_id: String) -> Dictionary:
	var record := CustomSetsStore.get_set(set_id)
	if record.is_empty():
		return _failure("no_set")
	var manifest_pairs: Array[Dictionary] = []
	var files := {}
	var skipped := 0
	for pair_id in CustomSetsStore.get_pair_ids(set_id):
		var pair := CustomSetsStore.get_pair(set_id, pair_id)
		if pair.is_empty():
			continue
		var word_a := str(pair.get("word_a", "")).strip_edges()
		var word_b := str(pair.get("word_b", "")).strip_edges()
		if word_a.is_empty() or word_b.is_empty():
			skipped += 1
			continue
		var item := {"id": pair_id, "word_a": word_a, "word_b": word_b}
		for key: String in SetPackageFormat.MEDIA_KEYS:
			var media := str(pair.get(key, "")).strip_edges()
			if media.is_empty():
				continue
			var extension := SetPackageFormat.extension_of(media)
			var is_image := key.begins_with("image_")
			var allowed := SetPackageFormat.IMAGE_EXTENSIONS if is_image else SetPackageFormat.AUDIO_EXTENSIONS
			if not allowed.has(extension):
				skipped += 1
				continue
			var bytes := _read_file_bytes(media)
			if bytes.is_empty():
				skipped += 1
				continue
			var side := key.substr(key.length() - 1, 1)
			var zip_path := SetPackageFormat.MEDIA_PREFIX + pair_id + "_" + side + "." + extension
			files[zip_path] = bytes
			item[key] = zip_path
		manifest_pairs.append(item)
	if manifest_pairs.is_empty():
		return _failure("no_entries")
	var manifest := SetPackageFormat.build_manifest(
			str(record.get("name", "")),
			str(record.get("contrast_id", "")),
			manifest_pairs)
	var checked := SetPackageFormat.validate_manifest(manifest, files)
	if not bool(checked.get("ok", false)):
		return _failure(str(checked.get("error", "bad_manifest")))
	var total_bytes := 0
	for raw_path in files.keys():
		total_bytes += (files[raw_path] as PackedByteArray).size()
	var total_error := SetPackageFormat.check_uncompressed_size(total_bytes)
	if not total_error.is_empty():
		return _failure(total_error)
	return {
		"ok": true,
		"error": "",
		"manifest": checked.get("manifest", {}) as Dictionary,
		"files": files,
		"skipped": skipped,
	}


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size := file.get_length()
	file.close()
	return size


static func _read_file_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"path": "",
		"name": "",
		"skipped": 0,
	}
