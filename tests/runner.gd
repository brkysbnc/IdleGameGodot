extends Node
## Autoload gerektiren testleri calistirir (autoload'lar sahne modunda kayitli olur).
## Kullanim:
##   godot --headless --path . res://tests/runner.tscn -- res://tests/economy_test.gd
## Test script'i `extends Node` olmali; _ready icinde calisir ve get_tree().quit(kod) ile cikar.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("HATA: test script yolu verilmedi (-- res://tests/xxx_test.gd).")
		get_tree().quit(1)
		return
	var script: Script = load(args[0])
	if script == null:
		printerr("HATA: '%s' yuklenemedi." % args[0])
		get_tree().quit(1)
		return
	add_child(script.new())
