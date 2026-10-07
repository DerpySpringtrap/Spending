extends Control
## Friends-only co-op: host a game or join a friend by address, pick heroes,
## and (host) start the run. No public matchmaking.

const CFG_PATH := "user://coop.cfg"
const CLASS_ORDER: Array[StringName] = [&"pyre_warden", &"moonblade", &"hollow_scribe", &"rootmother"]

var _name_edit: LineEdit
var _port_edit: LineEdit
var _address_edit: LineEdit
var _connect_box: VBoxContainer
var _lobby_box: VBoxContainer
var _players: VBoxContainer
var _classes: HBoxContainer
var _start: Button
var _status: Label
var _error: Label
var _host_info: Label


func _ready() -> void:
	UIBuild.backdrop(self, 0.45)
	var column := UIBuild.center_column(self, 18, 40)
	column.add_child(UIBuild.title("Co-op", 72))
	var sub := UIBuild.label("Play a run with friends. Invite only: one of you hosts, the others join with the host's address.", &"DimLabel", UIStyle.SIZE_BODY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	_error = UIBuild.label("", &"", UIStyle.SIZE_BODY, UIStyle.DAMAGE)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.custom_minimum_size.x = 1100
	column.add_child(_error)

	_connect_box = VBoxContainer.new()
	_connect_box.add_theme_constant_override("separation", 18)
	column.add_child(_connect_box)
	_build_connect()

	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 16)
	column.add_child(_lobby_box)
	_build_lobby()

	var back := UIBuild.button("Back", false, Vector2(240, 56))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		Coop.leave()
		GameManager.go_to_screen(&"main_menu"))
	column.add_child(back)

	Coop.lobby_changed.connect(_refresh)
	Coop.session_failed.connect(func(reason: String):
		_error.text = reason
		_refresh())
	_refresh()


func _exit_tree() -> void:
	_save_cfg()


# --- Connect -----------------------------------------------------------------------

func _build_connect() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 12)
	name_row.add_child(UIBuild.label("Your name", &"", UIStyle.SIZE_BODY))
	_name_edit = _edit(cfg.get_value("coop", "name", "Player"), 320)
	_name_edit.max_length = 16
	name_row.add_child(_name_edit)
	_connect_box.add_child(name_row)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	_connect_box.add_child(row)

	var host := _panel(row, "Host a game")
	host.add_child(UIBuild.label("Your friends join you. Port (UDP):", &"DimLabel", UIStyle.SIZE_BODY))
	_port_edit = _edit(str(cfg.get_value("coop", "port", Coop.DEFAULT_PORT)), 200)
	host.add_child(_port_edit)
	var host_button := UIBuild.button("Host", true, Vector2(260, 60))
	host_button.pressed.connect(func():
		_error.text = ""
		var err := Coop.host_game(_port(), _name_edit.text)
		if err != "":
			_error.text = err
		_refresh())
	host.add_child(host_button)

	var join := _panel(row, "Join a friend")
	join.add_child(UIBuild.label("Host's address (and port):", &"DimLabel", UIStyle.SIZE_BODY))
	_address_edit = _edit(cfg.get_value("coop", "address", ""), 420)
	_address_edit.placeholder_text = "e.g. 100.71.4.20 or 192.168.1.15:24785"
	join.add_child(_address_edit)
	var join_button := UIBuild.button("Join", true, Vector2(260, 60))
	join_button.pressed.connect(_join)
	_address_edit.text_submitted.connect(func(_t): _join())
	join.add_child(join_button)


func _join() -> void:
	_error.text = ""
	var text := _address_edit.text.strip_edges()
	var address := text
	var port := _port()
	# "host:port" (IPv4 or a name); bare IPv6 addresses have several colons.
	if text.count(":") == 1:
		address = text.get_slice(":", 0)
		port = clampi(text.get_slice(":", 1).to_int(), 1, 65535)
	var err := Coop.join_game(address, port, _name_edit.text)
	if err != "":
		_error.text = err
	_refresh()


func _port() -> int:
	var port := _port_edit.text.strip_edges().to_int()
	return port if port > 0 and port < 65536 else Coop.DEFAULT_PORT


# --- Lobby -------------------------------------------------------------------------

func _build_lobby() -> void:
	_status = UIBuild.label("", &"HeadingLabel", UIStyle.SIZE_H2)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_box.add_child(_status)
	_host_info = UIBuild.label("", &"DimLabel", UIStyle.SIZE_BODY)
	_host_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_host_info.custom_minimum_size.x = 1100
	_lobby_box.add_child(_host_info)
	_players = VBoxContainer.new()
	_players.add_theme_constant_override("separation", 8)
	_lobby_box.add_child(_players)
	_lobby_box.add_child(UIBuild.label("Your hero", &"HeadingLabel", 22))
	_classes = HBoxContainer.new()
	_classes.alignment = BoxContainer.ALIGNMENT_CENTER
	_classes.add_theme_constant_override("separation", 12)
	_lobby_box.add_child(_classes)
	for id in CLASS_ORDER:
		var cls := ContentDB.get_character_class(id)
		if cls == null:
			continue
		var b := UIBuild.button(cls.display_name, false, Vector2(250, 56))
		b.disabled = not MetaProgress.is_class_unlocked(id)
		if b.disabled:
			b.tooltip_text = "Locked: unlock this hero in a solo run first."
		b.pressed.connect(func(): Coop.set_class(id))
		_classes.add_child(b)
	_start = UIBuild.button("Start Run", true, Vector2(320, 64))
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start.pressed.connect(func(): Coop.start_run(0))
	_lobby_box.add_child(_start)


func _refresh() -> void:
	if not is_inside_tree():
		return
	var in_lobby := Coop.state == Coop.State.LOBBY
	var joining := Coop.state == Coop.State.JOINING
	_connect_box.visible = not in_lobby and not joining
	_lobby_box.visible = in_lobby or joining
	_start.visible = Coop.is_host
	_start.disabled = Coop.lobby.size() < 2
	_classes.visible = in_lobby
	if joining:
		_status.text = "Connecting…"
		_host_info.text = ""
	elif Coop.is_host:
		_status.text = "Lobby (%d/%d) · you are hosting" % [Coop.lobby.size(), Coop.MAX_PLAYERS]
		_host_info.text = _address_hint()
	else:
		_status.text = "Lobby (%d/%d) · waiting for the host to start" % [Coop.lobby.size(), Coop.MAX_PLAYERS]
		_host_info.text = ""
	for child in _players.get_children():
		child.queue_free()
	var me := Coop.my_lobby_entry()
	for entry in Coop.lobby:
		var cls := ContentDB.get_character_class(StringName(entry.class_id))
		var tag := " (host)" if entry.id == 1 else ""
		var you := " · you" if not me.is_empty() and entry.id == me.id else ""
		var label := UIBuild.label("%s%s%s  —  %s" % [entry.name, tag, you, cls.display_name if cls else "?"], &"", UIStyle.SIZE_H2 - 6)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", cls.secondary_color.lerp(Color.WHITE, 0.3) if cls else Color.WHITE)
		_players.add_child(label)
	if Coop.is_host and Coop.lobby.size() < 2:
		var wait := UIBuild.label("Waiting for a friend to join…", &"DimLabel", UIStyle.SIZE_BODY)
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_players.add_child(wait)


## Where friends can reach this computer: its local addresses (a VPN like
## Tailscale or Radmin shows up here too) plus the port.
func _address_hint() -> String:
	var addresses: PackedStringArray = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			addresses.append(a)
	var port := _port()
	if addresses.is_empty():
		return "Friends join with your address and port %d." % port
	return "Friends join with one of your addresses: %s  ·  port %d\nSame Wi-Fi: use the 192.168… one. Over the internet: use your VPN address (Tailscale 100.x, Radmin 26.x) or your public IP with UDP port %d forwarded." % [
		",  ".join(addresses), port, port]


# --- Helpers -----------------------------------------------------------------------

func _panel(parent: Control, heading: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UIBuild.label(heading, &"HeadingLabel", UIStyle.SIZE_H2))
	return box


func _edit(text: String, width: float) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.custom_minimum_size = Vector2(width, 52)
	edit.add_theme_font_size_override("font_size", UIStyle.SIZE_BODY)
	return edit


func _save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("coop", "name", _name_edit.text.strip_edges())
	cfg.set_value("coop", "port", _port())
	cfg.set_value("coop", "address", _address_edit.text.strip_edges())
	cfg.save(CFG_PATH)
