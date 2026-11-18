class_name Result
extends RefCounted
## Value-or-error: the union that earns its keep.
##
## Fallible work — file loads, parsing, and one day the network —
## returns one of these instead of a null, a sentinel value, or a
## silent failure. The caller gets the value or the reason, and has
## to look at one of them. Part of lib/, see CODE_MANIFESTO.md.
##
##	var loaded := SaveGame.load_from(path)
##	if loaded.is_err():
##		push_warning(loaded.error())
##	var state: Dictionary = loaded.value_or({})

var _ok: bool
var _value: Variant
var _error: String


func _init(ok: bool, value: Variant = null, error: String = "") -> void:
	_ok = ok
	_value = value
	_error = error


static func ok(value: Variant = null) -> Result:
	return Result.new(true, value, "")


static func err(message: String) -> Result:
	return Result.new(false, null, message)


func is_ok() -> bool:
	return _ok


func is_err() -> bool:
	return not _ok


## Why it failed. Empty when it didn't.
func error() -> String:
	return _error


## The value, or the fallback when there isn't one.
func value_or(fallback: Variant) -> Variant:
	return _value if _ok else fallback


## The value, loudly. Asserts in development builds, with the error
## in the message — an unhandled failure should name itself.
func unwrap() -> Variant:
	assert(_ok, "Result.unwrap() on err: " + _error)
	return _value
