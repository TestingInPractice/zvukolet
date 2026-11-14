extends Node
## Минимальный логгер приложения.
##
## Единая точка для сообщений: печатает строку с уровнем, тегом и словарём
## полей. Autoload-синглтон AppLogger. Намеренно простой: без файлов и ротации,
## чтобы не тащить инфраструктуру в первый вертикальный срез.

const PREFIX := "[Zvukolet]"


func info(tag: String, message: String, fields: Dictionary = {}) -> void:
	_emit("INFO", tag, message, fields)


func warning(tag: String, message: String, fields: Dictionary = {}) -> void:
	_emit("WARN", tag, message, fields)


func error(tag: String, message: String, fields: Dictionary = {}) -> void:
	_emit("ERROR", tag, message, fields)


func _emit(level: String, tag: String, message: String, fields: Dictionary) -> void:
	var suffix := ""
	if not fields.is_empty():
		suffix = " " + JSON.stringify(fields)
	var line := "%s %s [%s] %s%s" % [PREFIX, level, tag, message, suffix]
	if level == "ERROR":
		printerr(line)
	else:
		print(line)
