extends SceneTree
## Schreibt ground_ops/data/ground_rules_<stufe>.tres aus GroundRules.defaults_for(),
## mit allen Werten ausgeschrieben (danach sind die .tres maßgeblich und von Hand änderbar).
## Aufruf: godot --headless --path game --script res://ground_ops/data/make_ground_rules.gd


func _init() -> void:
	for r in 3:
		var g := GroundRules.defaults_for(r)
		var p := GroundRules.PATH % MatchRules.ground_realism_name(r)
		var s := "[gd_resource type=\"Resource\" script_class=\"GroundRules\" format=3]\n\n"
		s += "[ext_resource type=\"Script\" path=\"res://ground_ops/data/ground_rules.gd\" id=\"1_rules\"]\n\n"
		s += "[resource]\nscript = ExtResource(\"1_rules\")\n"
		for prop in g.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
				s += "%s = %s\n" % [prop.name, var_to_str(g.get(prop.name))]
		var f := FileAccess.open(ProjectSettings.globalize_path(p), FileAccess.WRITE)
		f.store_string(s)
		f.close()
		print(p)
	quit()
