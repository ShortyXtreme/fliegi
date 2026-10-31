class_name Authority
extends RefCounted
## Zentrale Stelle für "wer darf Zustand ändern?".
## Offline ist die lokale Instanz Peer 1 = Server. Ab M3 entscheidet hier
## das MultiplayerAPI. Zustandsänderungen (Sitzbelegung, Respawn, Modus)
## sollen immer über is_server() abgesichert werden.

static func is_server() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return true
	return tree.root.multiplayer.is_server()


static func local_peer_id() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 1
	return tree.root.multiplayer.get_unique_id()
