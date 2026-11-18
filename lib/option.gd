class_name Option
extends RefCounted
## A nullable with manners: a value, or an explicit nothing.
##
## GDScript value types can't be null and reference types shouldn't
## smuggle nulls through the logic — Option makes absence a thing
## the caller must handle, in the open. Part of lib/, the scaffolding
## shelf described in CODE_MANIFESTO.md.
##
##	var found := Option.from_nullable(enemies.get("leader"))
##	var leader_pos: Vector3 = found.map(func(e): return e["pos"]).value_or(Vector3.ZERO)

var _has: bool
var _value: Variant


func _init(has: bool = false, value: Variant = null) -> void:
	_has = has
	_value = value


static func some(value: Variant) -> Option:
	return Option.new(true, value)


static func none() -> Option:
	return Option.new(false, null)


## Wrap anything that might be null (a Dictionary.get without a
## default, a node that may not exist) at the border.
static func from_nullable(value: Variant) -> Option:
	return Option.new(value != null, value)


func is_some() -> bool:
	return _has


func is_none() -> bool:
	return not _has


## The value, or the fallback when there isn't one. This is the
## null-coalescing operator GDScript doesn't have, as a method.
func value_or(fallback: Variant) -> Variant:
	return _value if _has else fallback


## The value, loudly. Asserts in development builds — unwrapping a
## none is a bug, and it should say so where it happens.
func unwrap() -> Variant:
	assert(_has, "Option.unwrap() on none — the absence was never handled.")
	return _value


## Transform the value if there is one; none passes through.
func map(f: Callable) -> Option:
	if _has:
		return Option.some(f.call(_value))
	return Option.none()
