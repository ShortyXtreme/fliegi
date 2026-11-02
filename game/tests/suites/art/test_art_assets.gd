extends TestSuite
## Grafik (Pakete 11/12): Platz-Modelle und Figur importieren, Meshes und Vertrags-Marker vorhanden.

const DIR := "res://assets/ground/"
const MARKERS := {
	"fuel_truck": ["hose_reel", "seat_driver", "seat_passenger", "ground_clip", "wheel_FL", "wheel_RR"],
	"ammo_cart": ["seat_driver", "seat_passenger", "crate_slot_1", "crate_slot_2", "crate_slot_3",
		"crate_slot_4", "crate_slot_5", "crate_slot_6", "tailgate"],
	"ammo_crate": ["carry"], "fuel_drum": ["carry"], "hangar": ["door"], "fuel_depot": ["fuel_tap"],
	"ammo_bunker": ["ammo_door"], "toolbox": [], "extinguisher": [], "wheel_chocks": [], "parking_mark": [],
}
const CREW := "res://assets/ground/crew_mechanic.glb"
const CREW_ANIMS := ["idle", "walk", "run", "carry", "hose", "lift", "work", "enter"]


func _inst(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var ps = load(path)
	return ps.instantiate() if ps is PackedScene else null


func _meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for k in n.get_children():
		c += _meshes(k)
	return c


func test_ground_models_and_markers() -> Array:
	var bad: Array = []
	for nm in MARKERS:
		var n := _inst(DIR + nm + ".glb")
		if n == null:
			bad.append(nm + ": fehlt")
			continue
		if _meshes(n) == 0:
			bad.append(nm + ": kein Mesh")
		for m in MARKERS[nm]:
			if n.find_child(m, true, false) == null:
				bad.append("%s: Marker %s fehlt" % [nm, m])
		n.free()
	return [bad.is_empty(), str(bad)]


func test_crew_animations() -> Array:
	var n := _inst(CREW)
	if n == null:
		return [false, "crew_mechanic.glb fehlt"]
	var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
	var miss: Array = []
	for a in CREW_ANIMS:
		if ap == null or not ap.has_animation(a):
			miss.append(a)
	for b in ["Hips", "Spine", "Head", "LeftHand", "RightFoot"]:
		if sk == null or sk.find_bone(b) < 0:
			miss.append("Knochen " + b)
	for m in ["hand_R", "hand_L", "carry"]:
		if n.find_child(m, true, false) == null:
			miss.append("Marker " + m)
	var cnt := ap.get_animation_list().size() if ap else 0
	var loop_ok := ap != null and ap.has_animation("walk") and ap.get_animation("walk").loop_mode != Animation.LOOP_NONE
	n.free()
	return [miss.is_empty() and cnt >= 6 and loop_ok, "fehlt %s, Animationen %d, walk-Schleife %s" % [miss, cnt, loop_ok]]


func test_crew_anim_tree_states() -> Array:
	var n := _inst("res://characters/crew/anim/crew_model.tscn")
	if n == null:
		return [false, "crew_model.tscn fehlt"]
	var t: AnimationTree = n.find_child("AnimationTree", true, false)
	var sm = t.tree_root if t else null
	var miss: Array = []
	for s in CREW_ANIMS:
		if not (sm is AnimationNodeStateMachine and sm.has_node(StringName(s))):
			miss.append(s)
	var ap_ok := t != null and t.get_node_or_null(t.anim_player) is AnimationPlayer
	n.free()
	return [miss.is_empty() and ap_ok, "fehlende Zustände %s, AnimationPlayer %s" % [miss, ap_ok]]
