extends SceneTree
## Paket 12b (Grafik): erzeugt crew_anim_tree.tres (StateMachine, Zustände = CrewCharacter.ANIM_NAMES
## plus "lift") und crew_model.tscn (GLB + AnimationTree). Aufruf im Ordner game/:
##   godot --headless --path . --script res://characters/crew/anim/build_crew_anim.gd

const GLB := "res://assets/ground/crew_mechanic.glb"
const OUT_TREE := "res://characters/crew/anim/crew_anim_tree.tres"
const OUT_SCENE := "res://characters/crew/anim/crew_model.tscn"
const STATES := ["idle", "walk", "run", "carry", "hose", "lift", "work", "enter"]
const XFADE := 0.2


func _initialize() -> void:
	var sm := AnimationNodeStateMachine.new()
	for i in STATES.size():
		var a := AnimationNodeAnimation.new()
		a.animation = StringName(STATES[i])
		sm.add_node(StringName(STATES[i]), a, Vector2(200 * (i % 4), 150 * (i / 4)))
	var st := AnimationNodeStateMachineTransition.new()
	st.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition(&"Start", &"idle", st)
	for a in STATES:
		for b in STATES:
			if a != b:
				var t := AnimationNodeStateMachineTransition.new()
				t.xfade_time = XFADE
				sm.add_transition(StringName(a), StringName(b), t)
	# Einmal-Animationen kehren automatisch zu idle zurück
	for k in sm.get_transition_count():
		if not (String(sm.get_transition_from(k)) in ["lift", "enter"] and sm.get_transition_to(k) == &"idle"):
			continue
		var t := sm.get_transition(k)
		t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	var e1 := ResourceSaver.save(sm, OUT_TREE)
	var model: Node3D = (load(GLB) as PackedScene).instantiate()
	var root := Node3D.new()
	root.name = "CrewModel"
	root.add_child(model)
	model.owner = root
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = load(OUT_TREE)
	root.add_child(tree)
	tree.owner = root
	tree.anim_player = tree.get_path_to(ap)
	var ps := PackedScene.new()
	ps.pack(root)
	var e2 := ResourceSaver.save(ps, OUT_SCENE)
	print("AnimTree %s, Szene %s, Animationen %s" % [error_string(e1), error_string(e2), ap.get_animation_list()])
	root.free()
	quit(0 if e1 == OK and e2 == OK else 1)
