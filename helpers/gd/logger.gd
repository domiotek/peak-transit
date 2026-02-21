class_name GDLogger

var _file_name: String
var _file_handle: FileAccess

var _buffer_writes: bool = false
var _write_buffer: Array = []

var _keep_file_open: bool = false


func _init(file_name: String, buffer_writes: bool = false, keep_file_open: bool = false) -> void:
	_file_name = "user://logs/%s" % file_name
	_buffer_writes = buffer_writes
	_keep_file_open = keep_file_open

	var ensure_logs_dir_result = DirAccess.make_dir_recursive_absolute("user://logs")
	if ensure_logs_dir_result != OK:
		push_error("Failed to create logs directory: %s" % "user://logs")
		return

	var file_handle = _get_handle(true)
	if not file_handle:
		push_error("Failed to open log file: %s" % file_name)
		return

	file_handle.store_line("Log started at %s" % Time.get_date_string_from_system())
	flush()
	_return_handle()


func log(message: String) -> void:
	if _buffer_writes:
		_write_buffer.append(message)
	else:
		var file_handle = _get_handle()

		if not file_handle:
			push_error("Cannot write to log file: file handle is invalid.")
			return

		file_handle.store_line(message)
		_return_handle()


func flush() -> void:
	if not _buffer_writes:
		return

	var file_handle = _get_handle()

	if not file_handle:
		push_error("Cannot flush log file: file handle is invalid.")
		return

	for message in _write_buffer:
		file_handle.store_line(message)

	_write_buffer.clear()
	_return_handle()


func close() -> void:
	if _buffer_writes and _write_buffer.size() > 0:
		flush()

	if _file_handle:
		_file_handle.close()
		_file_handle = null


func _get_handle(truncate: bool = false) -> FileAccess:
	if _file_handle:
		return _file_handle

	if not FileAccess.file_exists(_file_name):
		var create_handle = FileAccess.open(_file_name, FileAccess.WRITE)
		if not create_handle:
			push_error("Failed to create log file: %s" % _file_name)
			return null
		create_handle.close()

	_file_handle = FileAccess.open(_file_name, FileAccess.READ_WRITE if not truncate else FileAccess.WRITE)

	if not _file_handle:
		push_error("Failed to reopen log file: %s" % _file_name)
		return null

	_file_handle.seek_end()

	return _file_handle


func _return_handle() -> void:
	if _keep_file_open:
		return

	if _file_handle:
		_file_handle.close()
		_file_handle = null


class DummyGDLogger extends GDLogger:
	func _init() -> void:
		pass


	func log(_message: String) -> void:
		pass


	func flush() -> void:
		pass


	func close() -> void:
		pass
