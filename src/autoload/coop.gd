extends Node
## Friends-only co-op sessions over the network (autoload: Coop).
##
## One player hosts (opens a UDP port); friends join with the host's address.
## There is no public matchmaking. Up to MAX_PLAYERS share a run.
##
## Lockstep: every client simulates the whole run. Player actions are sent to
## the host as small command dictionaries; the host numbers them and relays
## them to everyone (itself included) in one order, and every client applies
## them in that order. Combat is deterministic (seeded RNG), so all clients
## stay identical while only inputs cross the wire. Personal screens (rewards,
## shop, rest, events) run locally; when a player finishes, their whole seat
## is sent as a snapshot ("done" command). See GameManager's co-op section.

signal lobby_changed
## Couldn't connect, was turned away, or lost the connection (outside a run).
signal session_failed(reason: String)
## The host started the run: {"seed", "ascension", "final_act", "players": [...]}.
signal run_starting(payload: Dictionary, my_seat: int)
## A command, in the shared order (GameManager dispatches it).
signal command_received(cmd: Dictionary)

const DEFAULT_PORT := 24785
const MAX_PLAYERS := 4
## Bump when the command format changes.
const PROTOCOL := 1
const CONNECT_TIMEOUT := 10.0

enum State { OFFLINE, JOINING, LOBBY, IN_RUN, FINISHED }

var state := State.OFFLINE
var is_host := false
var my_name := "Player"
## Lobby entries: {"id": peer id, "name", "class_id"}. Seat order = list order.
var lobby: Array = []
## During a run: seat index -> peer id, and this client's seat.
var seat_peers: Array = []
var my_seat := 0
## Continuing a saved run: the host's save, and (on every client) the saved
## party [{"name", "class_id"}] plus where the run was. Joining players take
## the saved hero with their name (otherwise any free one).
var resume_state: Dictionary = {}
var resume_party: Array = []
var resume_where := ""
var _seq := 0
var _connect_timer: SceneTreeTimer


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_active() -> bool:
	return state != State.OFFLINE


func in_run() -> bool:
	return state == State.IN_RUN


## Fingerprint both sides compare before a friend may join.
func version_tag() -> String:
	return "%d|%s|%s" % [PROTOCOL, ProjectSettings.get_setting("application/config/version", "dev"), ContentDB.signature()]


# =============================================================================
# Hosting and joining
# =============================================================================

## Opens the lobby. Returns "" or an error to show. With [param resume] (a
## co-op save) the lobby continues that run instead of starting a new one.
func host_game(port: int, player_name: String, resume: Dictionary = {}) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return "Couldn't open port %d. Is another copy of the game already hosting?" % port
	multiplayer.multiplayer_peer = peer
	is_host = true
	my_name = _clean_name(player_name)
	state = State.LOBBY
	lobby = [{"id": 1, "name": my_name, "class_id": _default_class(0), "seat": -1}]
	if not resume.is_empty():
		resume_state = resume
		resume_where = "Act %d, floor %d" % [int(resume.get("act", 1)), int(resume.get("floor", 0))]
		for s in resume.get("seats", []):
			resume_party.append({"name": String(s.get("name", "?")), "class_id": String(s.get("class_id", ""))})
		_assign_seats()
	lobby_changed.emit()
	return ""


func is_resuming() -> bool:
	return not resume_party.is_empty()


## The host can start: 2+ players, and for a saved run every hero is taken.
func ready_to_start() -> bool:
	if lobby.size() < 2:
		return false
	if not is_resuming():
		return true
	return lobby.size() == resume_party.size() and lobby.all(func(p): return int(p.get("seat", -1)) >= 0)


## Saved run: players get the hero saved under their name, the rest fill the
## free heroes in join order.
func _assign_seats() -> void:
	if not is_resuming():
		return
	var taken := {}
	for entry in lobby:
		entry.seat = -1
	for entry in lobby:
		for i in resume_party.size():
			if not taken.has(i) and String(resume_party[i].name).to_lower() == String(entry.name).to_lower():
				entry.seat = i
				taken[i] = true
				break
	for entry in lobby:
		if int(entry.seat) >= 0:
			continue
		for i in resume_party.size():
			if not taken.has(i):
				entry.seat = i
				taken[i] = true
				break
	for entry in lobby:
		if int(entry.seat) >= 0:
			entry.class_id = resume_party[int(entry.seat)].class_id


## Starts connecting to a host. Returns "" or an error; the outcome arrives as
## lobby_changed (joined) or session_failed.
func join_game(address: String, port: int, player_name: String) -> String:
	leave()
	address = address.strip_edges()
	if address.is_empty():
		return "Type the host's address first."
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return "Couldn't start connecting to %s:%d." % [address, port]
	multiplayer.multiplayer_peer = peer
	is_host = false
	my_name = _clean_name(player_name)
	state = State.JOINING
	_connect_timer = get_tree().create_timer(CONNECT_TIMEOUT)
	_connect_timer.timeout.connect(func():
		if state == State.JOINING:
			_fail("No answer from %s:%d. Check the address, that the host is in the co-op lobby, and that the port is open." % [address, port]))
	return ""


## Leaves the session (lobby or run) and closes the connection.
func leave() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = State.OFFLINE
	is_host = false
	lobby = []
	resume_state = {}
	resume_party = []
	resume_where = ""
	seat_peers = []
	_seq = 0


## The run is over: stay connected for the summary but ignore disconnects.
func finish() -> void:
	if state == State.IN_RUN:
		state = State.FINISHED


func _fail(reason: String) -> void:
	var was_in_run := state == State.IN_RUN
	leave()
	if was_in_run:
		GameManager.coop_abort(reason)
	else:
		session_failed.emit(reason)


func _clean_name(text: String) -> String:
	var cleaned := text.strip_edges().left(16)
	return cleaned if not cleaned.is_empty() else "Player"


func _default_class(index: int) -> String:
	var order := [&"pyre_warden", &"moonblade", &"hollow_scribe", &"rootmother"]
	return String(order[index % order.size()])


# =============================================================================
# Lobby
# =============================================================================

func _on_connected_to_server() -> void:
	_hello.rpc_id(1, my_name, version_tag())


func _on_connection_failed() -> void:
	_fail("Couldn't reach the host.")


func _on_server_disconnected() -> void:
	if state == State.FINISHED:
		leave()
		return
	_fail("Lost the connection to the host.")


func _on_peer_connected(_id: int) -> void:
	pass  # Wait for their hello.


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	var who := _name_of(id)
	if state == State.IN_RUN:
		if seat_peers.has(id):
			var reason := "%s left the game." % who
			_abort_run.rpc(reason)
			# Give the message a moment to go out before closing the connection.
			get_tree().create_timer(0.3).timeout.connect(func(): _abort_run(reason))
		return
	if state == State.LOBBY:
		lobby = lobby.filter(func(p): return p.id != id)
		_assign_seats()
		_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func _hello(player_name: String, version: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	var reason := ""
	if version != version_tag():
		reason = "Your game is a different version from the host's. Both players need the same download."
	elif state != State.LOBBY:
		reason = "That run has already started."
	elif lobby.size() >= MAX_PLAYERS:
		reason = "The lobby is full (%d players)." % MAX_PLAYERS
	elif is_resuming() and lobby.size() >= resume_party.size():
		reason = "This saved run is for %d players, and they're all here." % resume_party.size()
	if reason != "":
		_rejected.rpc_id(id, reason)
		get_tree().create_timer(0.5).timeout.connect(func():
			var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
			if peer:
				peer.disconnect_peer(id))
		return
	lobby.append({"id": id, "name": _clean_name(player_name), "class_id": _default_class(lobby.size()), "seat": -1})
	_assign_seats()
	_broadcast_lobby()


@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	_fail(reason)


func _broadcast_lobby() -> void:
	_lobby_sync.rpc(lobby, resume_party, resume_where)
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _lobby_sync(list: Array, party: Array, where: String) -> void:
	lobby = list
	resume_party = party
	resume_where = where
	if state == State.JOINING:
		state = State.LOBBY
	lobby_changed.emit()


## Picks this player's hero in the lobby.
func set_class(class_id: StringName) -> void:
	if is_resuming():
		return  # Heroes come from the save.
	if is_host:
		_set_class_for(1, String(class_id))
	else:
		_pick_class.rpc_id(1, String(class_id))


@rpc("any_peer", "call_remote", "reliable")
func _pick_class(class_id: String) -> void:
	if is_host and state == State.LOBBY:
		_set_class_for(multiplayer.get_remote_sender_id(), class_id)


func _set_class_for(id: int, class_id: String) -> void:
	if ContentDB.get_character_class(StringName(class_id)) == null:
		return
	for entry in lobby:
		if entry.id == id:
			entry.class_id = class_id
	_broadcast_lobby()


func my_lobby_entry() -> Dictionary:
	var me := multiplayer.get_unique_id()
	for entry in lobby:
		if entry.id == me:
			return entry
	return {}


func _name_of(id: int) -> String:
	for entry in lobby:
		if entry.id == id:
			return entry.name
	return "A player"


# =============================================================================
# Starting the run
# =============================================================================

## Host: everyone in the lobby starts the same run.
func start_run(ascension: int = 0) -> void:
	if not is_host or state != State.LOBBY or not ready_to_start():
		return
	if is_resuming():
		var players: Array = []
		for i in resume_party.size():
			for entry in lobby:
				if int(entry.seat) == i:
					players.append({"id": entry.id, "name": resume_party[i].name, "class_id": resume_party[i].class_id})
		_begin_run.rpc({"resume": resume_state, "players": players})
		return
	var payload := {
		"seed": randi(), "ascension": ascension, "final_act": GameManager.final_act(),
		"players": lobby.duplicate(true),
	}
	_begin_run.rpc(payload)


@rpc("authority", "call_local", "reliable")
func _begin_run(payload: Dictionary) -> void:
	state = State.IN_RUN
	_seq = 0
	seat_peers = []
	var me := multiplayer.get_unique_id()
	my_seat = 0
	for i in payload.players.size():
		seat_peers.append(payload.players[i].id)
		if payload.players[i].id == me:
			my_seat = i
	run_starting.emit(payload, my_seat)


@rpc("authority", "call_remote", "reliable")
func _abort_run(reason: String) -> void:
	if state != State.IN_RUN:
		return
	leave()
	GameManager.coop_abort(reason)


# =============================================================================
# Commands (lockstep)
# =============================================================================

## Sends this player's action to everyone (in the host's order). [param cmd]
## needs "t" (type); "seat" is filled in.
func send(cmd: Dictionary) -> void:
	if state != State.IN_RUN:
		return
	cmd["seat"] = my_seat
	if is_host:
		_relay(cmd)
	else:
		_submit.rpc_id(1, cmd)


@rpc("any_peer", "call_remote", "reliable")
func _submit(cmd: Dictionary) -> void:
	if not is_host or state != State.IN_RUN:
		return
	var sender := multiplayer.get_remote_sender_id()
	var seat := int(cmd.get("seat", -1))
	if seat < 0 or seat >= seat_peers.size() or seat_peers[seat] != sender:
		push_warning("Coop: dropped a command from peer %d for seat %d" % [sender, seat])
		return
	_relay(cmd)


func _relay(cmd: Dictionary) -> void:
	_seq += 1
	cmd["n"] = _seq
	_deliver.rpc(cmd)


@rpc("authority", "call_local", "reliable")
func _deliver(cmd: Dictionary) -> void:
	if state != State.IN_RUN:
		return
	command_received.emit(cmd)
