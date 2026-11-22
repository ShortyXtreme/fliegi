class_name RadioChannel
extends RefCounted
## M3.5: Funkkanal = Rolle am Platz, als Daten: {id, number, name, role (Empfänger-Rolle), speaker,
## freq, commands[]}. Kanäle 1–4 jetzt (Tankwart, Munition, Reparatur, Bodenpersonal); spätere
## Kanäle 5+ (Werkstatt-Leitung, Nachschub, Platzleitung, Einsatzleiter) werden nur angehängt
## (docs/funk_konzept.md).
## Ist die Rolle von einem Spieler besetzt (operator_peer != 0), geht der Befehl als Anfrage an ihn
## (Signal request_sent), sonst handelt die KI: receiver.call(command, target) -> Anzahl Empfänger.
## Antworten (answer) landen im Protokoll log des Kanals (Antwortzeilen im Funkgerät).

signal request_sent(channel: RadioChannel, cmd: RadioCommand, target: Node)
signal answered(text: String)

const LOG_MAX := 12

var id: StringName = &""
var number := 0
var name := ""
## Empfänger-Rolle (&"fuel", &"ammo", &"repair", &"ground_crew"; später &"workshop", &"supply" …).
var role: StringName = &""
## Sprecher in den Antwortzeilen („Tankwart: tanke, 73 %“).
var speaker := ""
## Frequenzanzeige am Gerät (Tier I: Kurzwelle, MHz).
var freq := ""
var commands: Array = []
## Peer, der die Rolle besetzt (0 = KI).
var operator_peer := 0
## KI-Empfänger: func(command: int, target: Node, channel_id: StringName) -> int
var receiver := Callable()
## Antwortzeilen (neueste zuletzt): [{text, t}] mit t = Ticks in s.
var log: Array = []


static func make(p_id: StringName, p_number: int, p_name: String, p_role: StringName, p_speaker: String,
		p_freq: String, p_commands: Array) -> RadioChannel:
	var c := RadioChannel.new()
	c.id = p_id
	c.number = p_number
	c.name = p_name
	c.role = p_role
	c.speaker = p_speaker
	c.freq = p_freq
	c.commands = p_commands
	return c


## Die Kanäle des Bodenbetriebs (M3.5). Neue Rollen: hier anhängen.
static func default_channels() -> Array:
	var C := GroundCrewBrain.Command
	var R := func(i: StringName, l: String, c: int, h: String) -> RadioCommand: return RadioCommand.make(i, l, c, h)
	return [
		make(&"fuel", 1, "Tankwart", &"fuel", "Tankwart", "3,150", [
			R.call(&"call_truck", "Tankwagen rufen", C.CALL_TRUCK, "nur heranfahren – du tankst selbst"),
			R.call(&"truck_home", "Tankwagen wegschicken", C.TRUCK_HOME, "Schlauch ein, zurück zum Stellplatz"),
			R.call(&"refuel", "Volltanken", C.FUEL_ONLY, "tankt voll, räumt auf, fährt zurück"),
			R.call(&"status", "Status?", C.STATUS, "grobe Lage: wie voll?")]),
		make(&"ammo", 2, "Munition", &"ammo", "Munitionswart", "3,275", [
			R.call(&"call_cart", "Munitionswagen rufen", C.CALL_CART, "nur heranfahren – du lädst selbst"),
			R.call(&"cart_home", "Munitionswagen wegschicken", C.CART_HOME, "zurück zum Stellplatz"),
			R.call(&"rearm", "Aufmunitionieren", C.AMMO_ONLY, "lädt beide MG, räumt auf, fährt zurück"),
			R.call(&"status", "Status?", C.STATUS, "grobe Lage: wie weit?")]),
		make(&"repair", 3, "Reparatur", &"repair", "Mechaniker", "3,400", [
			R.call(&"call_mech", "Mechaniker rufen", C.CALL_MECH, "kommt an die Maschine und wartet"),
			R.call(&"mech_home", "Mechaniker wegschicken", C.MECH_HOME, "zurück zum Stellplatz"),
			R.call(&"repair", "Reparieren", C.REPAIR, "kleine Reparatur, danach zurück"),
			R.call(&"status", "Status?", C.STATUS, "grobe Lage: wie lange noch?")]),
		make(&"crew", 4, "Bodenpersonal", &"ground_crew", "Bodenpersonal", "3,525", [
			R.call(&"full", "Kompletter Ablauf", C.FULL_SERVICE, "Tanken, Munition, Reparatur, danach alles zurück"),
			R.call(&"all_home", "Alle wegschicken", C.ALL_HOME, "Wagen zurück, alle zum Stellplatz"),
			R.call(&"status", "Status?", C.STATUS, "grobe Lage der Abfertigung")]),
	]


## Befehl senden. Rückgabe: Anzahl Empfänger (Anfrage an einen Spieler = 1).
func send(cmd: RadioCommand, target: Node) -> int:
	if cmd == null or cmd.is_menu():
		return 0
	if operator_peer != 0:
		request_sent.emit(self, cmd, target)
		answer("Anfrage gesendet: %s" % cmd.label)
		return 1
	if receiver.is_valid():
		var n := int(receiver.call(cmd.command, target, id))
		if n == 0:
			answer("%s: nicht möglich – %s" % [speaker, cmd.label])
		return n
	answer("Keine Antwort auf Kanal %d" % number)
	return 0


func answer(text: String) -> void:
	log.append({text = text, t = Time.get_ticks_msec() / 1000.0})
	while log.size() > LOG_MAX:
		log.pop_front()
	answered.emit(text)


func title() -> String:
	return "Kanal %d – %s" % [number, name]
