class_name SetPackageFormat
extends RefCounted
## Формат файла набора .zvset: манифест, пути, расширения и лимиты.
##
## Класс чистый: не читает файлы и не знает про UI. Все проверки возвращают
## коды ошибок, а человеческий текст собирает user_message().

const FORMAT := "zvukolet-set"
const VERSION := 1
const EXTENSION := "zvset"
const MANIFEST_NAME := "manifest.json"
const MEDIA_PREFIX := "media/"

const IMAGE_EXTENSIONS := ["png", "webp", "jpg", "jpeg"]
const AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]
const MEDIA_KEYS := ["image_a", "image_b", "audio_a", "audio_b"]

const MAX_PACKAGE_BYTES := 25 * 1024 * 1024
const MAX_MANIFEST_BYTES := 256 * 1024
const MAX_IMAGE_BYTES := 5 * 1024 * 1024
const MAX_AUDIO_BYTES := 10 * 1024 * 1024
const MAX_TOTAL_UNCOMPRESSED_BYTES := 60 * 1024 * 1024
const MAX_WORD_LENGTH := 40
const MAX_NAME_LENGTH := 60
const MAX_FILES := 80
const MAX_PAIRS := 40


## Собирает манифест из пар набора. Порядок пар сохраняется.
static func build_manifest(set_name: String, contrast_id: String, pairs: Array) -> Dictionary:
	var normalized_name := set_name.strip_edges()
	if normalized_name.length() > MAX_NAME_LENGTH:
		normalized_name = normalized_name.substr(0, MAX_NAME_LENGTH)
	var entries: Array[Dictionary] = []
	for raw_pair: Variant in pairs:
		if not (raw_pair is Dictionary):
			continue
		var source: Dictionary = raw_pair
		var item := {}
		var pair_id := str(source.get("id", "")).strip_edges()
		if not pair_id.is_empty():
			item["id"] = pair_id
		var word_a := str(source.get("word_a", "")).strip_edges()
		if not word_a.is_empty():
			item["word_a"] = word_a.substr(0, MAX_WORD_LENGTH)
		var word_b := str(source.get("word_b", "")).strip_edges()
		if not word_b.is_empty():
			item["word_b"] = word_b.substr(0, MAX_WORD_LENGTH)
		for key: String in MEDIA_KEYS:
			var media := str(source.get(key, "")).strip_edges()
			if not media.is_empty():
				item[key] = media
		if not item.is_empty():
			entries.append(item)
	return {
		"format": FORMAT,
		"version": VERSION,
		"name": normalized_name,
		"contrast_id": contrast_id,
		"pairs": entries,
	}


## Проверяет манифест и файлы архива. Возвращает {ok, error, manifest}.
static func validate_manifest(raw: Variant, files: Dictionary) -> Dictionary:
	if not (raw is Dictionary):
		return _failure("bad_manifest")
	var manifest: Dictionary = raw
	if str(manifest.get("format", "")) != FORMAT:
		return _failure("bad_format")
	if int(manifest.get("version", -1)) != VERSION:
		return _failure("bad_version")
	var set_name := str(manifest.get("name", "")).strip_edges()
	if set_name.is_empty():
		return _failure("empty_name")
	if set_name.length() > MAX_NAME_LENGTH:
		return _failure("name_too_long")
	var contrast_id := str(manifest.get("contrast_id", "")).strip_edges()
	if contrast_id.is_empty():
		return _failure("empty_contrast")
	var raw_pairs: Variant = manifest.get("pairs", null)
	if not (raw_pairs is Array):
		return _failure("bad_pairs")
	var source_pairs: Array = raw_pairs
	if source_pairs.is_empty():
		return _failure("bad_pairs")
	if source_pairs.size() > MAX_PAIRS:
		return _failure("too_many_pairs")
	var pairs: Array[Dictionary] = []
	var seen_ids := {}
	for raw_entry: Variant in source_pairs:
		if not (raw_entry is Dictionary):
			return _failure("bad_entry")
		var entry: Dictionary = raw_entry
		var pair_id := str(entry.get("id", "")).strip_edges()
		if pair_id.is_empty():
			return _failure("bad_entry")
		if seen_ids.has(pair_id):
			return _failure("duplicate_pair")
		seen_ids[pair_id] = true
		var word_a := str(entry.get("word_a", "")).strip_edges()
		var word_b := str(entry.get("word_b", "")).strip_edges()
		if word_a.is_empty() or word_b.is_empty():
			return _failure("empty_word")
		if word_a.length() > MAX_WORD_LENGTH or word_b.length() > MAX_WORD_LENGTH:
			return _failure("word_too_long")
		var item := {"id": pair_id, "word_a": word_a, "word_b": word_b}
		for key: String in MEDIA_KEYS:
			var media := str(entry.get(key, "")).strip_edges()
			if media.is_empty():
				continue
			var path_check := safe_relative_path(media, MEDIA_PREFIX)
			if not bool(path_check.get("ok", false)):
				return _failure(str(path_check.get("error", "bad_path")))
			var normalized := str(path_check.get("path", ""))
			var extension := extension_of(normalized)
			var is_image := key.begins_with("image_")
			var allowed := IMAGE_EXTENSIONS if is_image else AUDIO_EXTENSIONS
			if not allowed.has(extension):
				return _failure("bad_extension")
			if not files.has(normalized):
				return _failure("missing_media")
			var blob: Variant = files[normalized]
			if typeof(blob) != TYPE_PACKED_BYTE_ARRAY:
				return _failure("empty_media")
			var bytes: PackedByteArray = blob
			if bytes.is_empty():
				return _failure("empty_media")
			var limit := MAX_IMAGE_BYTES if is_image else MAX_AUDIO_BYTES
			if bytes.size() > limit:
				return _failure("too_large")
			item[key] = normalized
		pairs.append(item)
	return {
		"ok": true,
		"error": "",
		"manifest": {
			"format": FORMAT,
			"version": VERSION,
			"name": set_name,
			"contrast_id": contrast_id,
			"pairs": pairs,
		},
	}


## Проверяет относительный путь внутри media/.
static func safe_relative_path(path: String, prefix: String) -> Dictionary:
	var clean := path.strip_edges()
	if clean.is_empty():
		return _failure("empty_path")
	if clean.begins_with("/") or clean.begins_with("\\"):
		return _failure("bad_path")
	if clean.contains("\\") or clean.contains("://"):
		return _failure("bad_path")
	if clean.length() >= 2 and clean.substr(1, 1) == ":":
		return _failure("bad_path")
	var expected_prefix := prefix.trim_suffix("/") + "/"
	if not clean.begins_with(expected_prefix):
		return _failure("bad_path")
	var parts := clean.split("/", true)
	if parts.size() < 2:
		return _failure("bad_path")
	for part in parts:
		if part.is_empty() or part == "." or part == "..":
			return _failure("bad_path")
		if not part.is_valid_filename():
			return _failure("bad_path")
	return {"ok": true, "error": "", "path": clean}


static func extension_of(path: String) -> String:
	return path.get_extension().to_lower()


## Пустая строка, если размер пакета допустим, иначе код ошибки.
static func check_package_size(size_bytes: int) -> String:
	if size_bytes > MAX_PACKAGE_BYTES:
		return "too_large"
	return ""


## Пустая строка, если распакованный размер допустим, иначе код ошибки.
static func check_uncompressed_size(size_bytes: int) -> String:
	if size_bytes > MAX_TOTAL_UNCOMPRESSED_BYTES:
		return "too_large"
	return ""


## Человеческий текст по коду ошибки.
static func user_message(code: String) -> String:
	match code:
		"cancelled":
			return "выбор отменён"
		"bad_archive":
			return "не удалось прочитать файл набора"
		"missing_manifest":
			return "в файле нет manifest.json"
		"bad_manifest":
			return "manifest.json повреждён"
		"bad_format":
			return "это не файл набора Звуколёта"
		"bad_version":
			return "версия файла не поддерживается"
		"empty_name":
			return "в наборе нет названия"
		"name_too_long":
			return "название набора слишком длинное"
		"empty_contrast":
			return "в наборе не указан контраст"
		"bad_pairs":
			return "в наборе нет пар"
		"too_many_pairs":
			return "в наборе слишком много пар"
		"bad_entry":
			return "запись пары повреждена"
		"duplicate_pair":
			return "в наборе повторяется пара"
		"empty_word":
			return "у пары нет одного из слов"
		"word_too_long":
			return "слишком длинное слово"
		"bad_path", "empty_path":
			return "в наборе недопустимый путь к файлу"
		"bad_extension":
			return "неподдерживаемый формат файла"
		"missing_media":
			return "в наборе нет файла, указанного в manifest.json"
		"empty_media":
			return "файл в наборе пустой"
		"too_large":
			return "файл набора слишком большой"
		"too_many_files":
			return "в наборе слишком много файлов"
		"no_set":
			return "набор не найден"
		"no_entries":
			return "в наборе нет заполненных пар"
		"write_failed", "read_failed":
			return "не удалось сохранить файл набора"
		"unsupported_type":
			return "формат файла не поддерживается"
		_:
			return "не удалось обработать набор"


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "error": code, "manifest": {}}
