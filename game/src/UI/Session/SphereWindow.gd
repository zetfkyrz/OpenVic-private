extends "res://src/UI/Session/Vic2Window.gd"
## The spheres of influence (version 92, docs/PLAN_SPHERES.md): the sphere of the player (a banner in its colour, the kind, the members),
## founding a sphere (a great power), the influence of the player on the countries and the invitation, leaving, the colour of the sphere,
## the influence of the great powers on the player and all the spheres of the world. Opened by the plate "Сферы" of the top bar.
## A double click on a country opens the diplomacy with it, as a click on a flag does everywhere. Version 93: the effects of the kinds, the
## leader changes the kind (once in SPHERE_KIND_CHANGE_MONTHS), the tribute of the imperial sphere, the single market of the customs union.
## Version 94: the principles in the slots (their level grows with the years), chosen by the leader.

const _SIZE: Vector2 = Vector2(940, 700)

const KIND_NAMES: PackedStringArray = ["Таможенный союз", "Имперская сфера", "Военный союз", "Идеологический союз", "Альянс"]
const KIND_DESCRIPTIONS: PackedStringArray = [
	"нет пошлин между членами; страны единого рынка (связанные с лидером сухопутной границей) торгуют между собой в первую очередь; эмигранты едут к членам на 50 % охотнее",
	"члены-ИИ вступают в войны лидера (при отношениях с ним от 50), +25 к отношениям между членами, лидеру каждый день 5 % дохода казны членов, процессы отношений между членами бесплатны",
	"войны между членами запрещены; лидер втягивает членов в свои войны, отказ — −5 % престижа; земля членов для армий — как своя (снабжение, пополнение, бонус родной земли)",
	"шанс принятия законов +10 %, +25 к отношениям между членами",
	"без ограничений на число великих держав, бесплатная дипломатия, +5 % к исследованиям (нужна технология «Многосторонние союзы»)",
]
const KIND_SHORT_NAMES: PackedStringArray = ["Тамож. союз", "Имперская", "Военный союз", "Идеолог. союз", "Альянс"]
const _KIND_FOR_FOUNDING: PackedInt32Array = [0, 1, 2, 3]

# The reasons of the simulation (Sphere.cpp), in Russian
const _REASONS: Dictionary = {
	"no such kind of sphere": "нет такого вида сферы",
	"the Alliance needs the technology of the multilateral alliances": "для Альянса нужна технология «Многосторонние союзы»",
	"only a great power founds a sphere": "сферу основывает только великая держава",
	"the country already is in a sphere": "страна уже в сфере",
	"the country leads no sphere": "у вас нет своей сферы",
	"no such country": "нет такой страны",
	"only one great power in a sphere (the Alliance allows more)": "в сфере только одна великая держава (в Альянсе можно больше)",
	"the country already is a member": "уже член вашей сферы",
	"at war": "вы в войне с этой страной",
	"the sphere already is of this kind": "сфера уже этого вида",
	"the kind was changed not long ago": "вид меняли недавно",
	"members are at war with each other": "члены сферы воюют друг с другом",
	"the sphere has no such slot (more countries open more slots)": "ячейка закрыта: больше стран в сфере — больше ячеек",
	"the slot is empty": "ячейка пуста",
	"no such principle": "нет такого принципа",
	"the principle already is in this slot": "этот принцип уже в ячейке",
	"the principle already is in another slot": "этот принцип уже в другой ячейке",
}

# The principles (version 94): the names by the identifier of the data (a principle of a mod shows its identifier)
const PRINCIPLE_NAMES: Dictionary = {
	"military_industry": "Военная промышленность",
	"specialists_exchange": "Обмен специалистами",
	"teachers_exchange": "Обмен учителями",
	"trading_posts": "Торговые конторы",
	"banking_union": "Банковский союз",
	"mutual_police": "Взаимная полиция",
}

var _info: Dictionary = {}
var _selected_influence: int = -1

var _banner: PanelContainer
var _banner_style: StyleBoxFlat
var _banner_title: Label
var _banner_text: Label
var _found_row: HBoxContainer
var _found_kind: OptionButton
var _found_button: Button
var _found_reason: Label
var _members_caption: Label
var _members_tree: Tree
var _leader_row: HBoxContainer
var _kind_row: HBoxContainer
var _kind_option: OptionButton
var _kind_button: Button
var _kind_reason: Label
var _colour_button: ColorPickerButton
var _leave_button: Button
var _principles_caption: Label
var _principle_status: Array[Label] = []
var _principle_option: Array[OptionButton] = []
var _principle_button: Array[Button] = []
var _principle_reason: Array[Label] = []
var _principle_rows: Array[HBoxContainer] = []
var _influence_caption: Label
var _influence_tree: Tree
var _invite_button: Button
var _invite_reason: Label
var _spheres_tree: Tree


func _ready() -> void:
	setup(_SIZE, "Сферы влияния")
	add_to_group(&"sphere_window")

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override(&"separation", 6)
	scroll.add_child(root)

	# the banner of the sphere, in its colour
	_banner = PanelContainer.new()
	_banner_style = StyleBoxFlat.new()
	_banner_style.set_corner_radius_all(6)
	_banner_style.content_margin_left = 12.0
	_banner_style.content_margin_right = 12.0
	_banner_style.content_margin_top = 6.0
	_banner_style.content_margin_bottom = 6.0
	_banner.add_theme_stylebox_override(&"panel", _banner_style)
	root.add_child(_banner)
	var banner_box := VBoxContainer.new()
	_banner.add_child(banner_box)
	_banner_title = Label.new()
	_banner_title.add_theme_font_size_override(&"font_size", 20)
	banner_box.add_child(_banner_title)
	_banner_text = Label.new()
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_box.add_child(_banner_text)

	# founding (a great power out of the spheres)
	_found_row = HBoxContainer.new()
	root.add_child(_found_row)
	_found_kind = OptionButton.new()
	for kind: int in _KIND_FOR_FOUNDING:
		_found_kind.add_item(KIND_NAMES[kind], kind)
	_found_kind.item_selected.connect(func(_index: int) -> void: _update_found())
	_found_row.add_child(_found_kind)
	_found_button = Button.new()
	_found_button.text = "Основать сферу"
	_found_button.pressed.connect(_on_found_pressed)
	_found_row.add_child(_found_button)
	_found_reason = Label.new()
	_found_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_found_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_found_row.add_child(_found_reason)

	# the members
	_members_caption = Label.new()
	root.add_child(_members_caption)
	_members_tree = _make_tree(["Страна", "Отношения с лидером", "Влияние лидера", "Историческая"], 130)
	_members_tree.item_activated.connect(_on_country_activated.bind(_members_tree))
	root.add_child(_members_tree)

	_leader_row = HBoxContainer.new()
	root.add_child(_leader_row)
	var colour_label := Label.new()
	colour_label.text = "Цвет сферы:"
	_leader_row.add_child(colour_label)
	_colour_button = ColorPickerButton.new()
	_colour_button.custom_minimum_size = Vector2(60, 24)
	_colour_button.edit_alpha = false
	_colour_button.popup_closed.connect(func() -> void: PlayerSingleton.set_sphere_colour(_colour_button.color))
	_leader_row.add_child(_colour_button)
	# the leader changes the kind (version 93)
	_kind_row = HBoxContainer.new()
	root.add_child(_kind_row)
	_kind_option = OptionButton.new()
	for kind: int in _KIND_FOR_FOUNDING:
		_kind_option.add_item(KIND_NAMES[kind], kind)
	_kind_option.item_selected.connect(func(_index: int) -> void: _update_kind_change())
	_kind_row.add_child(_kind_option)
	_kind_button = Button.new()
	_kind_button.text = "Сменить вид"
	_kind_button.pressed.connect(func() -> void: PlayerSingleton.set_sphere_kind(_kind_option.get_selected_id()))
	_kind_row.add_child(_kind_button)
	_kind_reason = Label.new()
	_kind_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_kind_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kind_row.add_child(_kind_reason)
	# the principles (version 94)
	_principles_caption = Label.new()
	_principles_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_principles_caption)
	for slot: int in 3:
		var row := HBoxContainer.new()
		root.add_child(row)
		_principle_rows.append(row)
		var status := Label.new()
		status.custom_minimum_size = Vector2(380, 0)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(status)
		_principle_status.append(status)
		var option := OptionButton.new()
		option.custom_minimum_size = Vector2(210, 0)
		option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		option.item_selected.connect(func(_index: int) -> void: _update_principle_row(slot))
		row.add_child(option)
		_principle_option.append(option)
		var button := Button.new()
		button.text = "Поставить"
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_principle_pressed.bind(slot))
		row.add_child(button)
		_principle_button.append(button)
		var reason := Label.new()
		reason.custom_minimum_size = Vector2(200, 0)
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(reason)
		_principle_reason.append(reason)
	_leave_button = Button.new()
	_leave_button.text = "Выйти из сферы"
	_leave_button.pressed.connect(func() -> void: PlayerSingleton.leave_sphere())
	root.add_child(_leave_button)

	# the influence
	_influence_caption = Label.new()
	_influence_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_influence_caption)
	_influence_tree = _make_tree(["Страна", "Влияние", "Торговля", "Инвестиции", "Множитель", "Отношения", "Сфера"], 170)
	_influence_tree.item_selected.connect(_on_influence_selected)
	_influence_tree.item_activated.connect(_on_country_activated.bind(_influence_tree))
	root.add_child(_influence_tree)
	var invite_row := HBoxContainer.new()
	root.add_child(invite_row)
	_invite_button = Button.new()
	_invite_button.text = "Пригласить в сферу"
	_invite_button.pressed.connect(_on_invite_pressed)
	invite_row.add_child(_invite_button)
	_invite_reason = Label.new()
	_invite_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_invite_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invite_row.add_child(_invite_reason)

	# all the spheres of the world
	var spheres_caption := Label.new()
	spheres_caption.text = "Сферы мира:"
	root.add_child(spheres_caption)
	_spheres_tree = _make_tree(["Лидер", "Вид", "Членов", "Основана"], 130)
	_spheres_tree.set_column_custom_minimum_width(1, 190)
	_spheres_tree.set_column_custom_minimum_width(2, 80)
	_spheres_tree.set_column_custom_minimum_width(3, 110)
	_spheres_tree.item_activated.connect(_on_country_activated.bind(_spheres_tree))
	root.add_child(_spheres_tree)

	GameSingleton.gamestate_updated.connect(_refresh)


func _make_tree(titles: PackedStringArray, height: float) -> Tree:
	var tree := Tree.new()
	tree.columns = titles.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.custom_minimum_size = Vector2(0, height)
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for column: int in titles.size():
		tree.set_column_title(column, titles[column])
		tree.set_column_expand(column, column == 0)
	tree.set_column_custom_minimum_width(0, 200)
	return tree


## Opens the window, or closes it when it is open (the plate of the top bar)
func toggle() -> void:
	if visible:
		close()
	else:
		_refresh_inner()
		open_window()


func _refresh() -> void:
	if visible:
		_refresh_inner()


static func _reason(text: String) -> String:
	return _REASONS.get(text, text)


static func sphere_name(sphere: Dictionary) -> String:
	return "%s — %s" % [KIND_NAMES[int(sphere[&"kind"])], sphere[&"leader_name"]]


func _refresh_inner() -> void:
	_info = PlayerSingleton.get_sphere_info()
	if _info.is_empty():
		return
	var own: Dictionary = _info[&"own"]
	var in_sphere: bool = not own.is_empty()
	var is_leader: bool = _info[&"is_leader"]

	# the banner
	if in_sphere:
		var colour: Color = own[&"colour"]
		_banner_style.bg_color = colour.darkened(0.15)
		var text_colour: Color = Color.WHITE if colour.get_luminance() < 0.55 else Color(0.08, 0.05, 0.03)
		_banner_title.add_theme_color_override(&"font_color", text_colour)
		_banner_text.add_theme_color_override(&"font_color", text_colour)
		_banner_title.text = sphere_name(own)
		var lines: PackedStringArray = [KIND_DESCRIPTIONS[int(own[&"kind"])] + ".", "Основана %s." % own[&"founded"]]
		if String(own[&"protected_until"]) != "":
			lines.append("Историческая сфера: держится до %s, даже если лидер не великая держава." % own[&"protected_until"])
		lines.append("Любая сфера: лидеру +25 к отношениям с каждым членом (не ниже −175), ИИ почти не воюет внутри сферы.")
		var kind: int = int(own[&"kind"])
		if kind == 0:
			lines.append("Ваша страна в едином рынке союза." if _info.get(&"single_market", false)
				else "Ваша страна вне единого рынка (нет сухопутной связи с лидером): торговля без пошлин, но без первой очереди.")
		elif kind == 1 and is_leader:
			lines.append("Дань членов вчера: %.2f £." % float(own.get(&"tribute", 0.0)))
		_banner_text.text = "\n".join(lines)
	else:
		_banner_style.bg_color = Color(0.3, 0.26, 0.2)
		_banner_title.add_theme_color_override(&"font_color", Color.WHITE)
		_banner_text.add_theme_color_override(&"font_color", Color.WHITE)
		_banner_title.text = "Ваша страна не в сфере"
		_banner_text.text = "Сферу основывает великая держава; страны вступают по её влиянию — торговле и инвестициям, умноженным на отношения и соседство." \
			if not _info[&"great_power"] else "Вы — великая держава и можете основать свою сферу."

	_found_row.visible = not in_sphere and _info[&"great_power"]
	_update_found()

	# the members
	_members_caption.visible = in_sphere
	_members_tree.visible = in_sphere
	_members_tree.clear()
	if in_sphere:
		var members: Array = own[&"members"]
		_members_caption.text = "Лидер: %s. Члены (%d):" % [own[&"leader_name"], members.size()]
		var root: TreeItem = _members_tree.create_item()
		for member: Dictionary in members:
			var item: TreeItem = _members_tree.create_item(root)
			item.set_text(0, member[&"name"])
			item.set_metadata(0, member[&"tag"])
			item.set_text(1, str(member[&"relation"]))
			item.set_text(2, "%.0f" % float(member[&"influence"]))
			item.set_text(3, "да" if member[&"protected"] else "")
	_leader_row.visible = is_leader
	_kind_row.visible = is_leader
	if is_leader:
		_colour_button.color = own[&"colour"]
		# the list offers another kind than the current one
		if _kind_option.get_selected_id() == int(own[&"kind"]):
			for index: int in _kind_option.item_count:
				if _kind_option.get_item_id(index) != int(own[&"kind"]):
					_kind_option.select(index)
					break
		_update_kind_change()
	_leave_button.visible = in_sphere and not is_leader
	_refresh_principles(own, in_sphere, is_leader)

	# the influence: of the player on the countries (a great power), else of the great powers on the player
	_influence_tree.clear()
	var influence_root: TreeItem = _influence_tree.create_item()
	var to_select: TreeItem = null
	if _info[&"great_power"] or is_leader:
		_influence_caption.text = "Ваше влияние на страны (1 % ВВП страны, купленный у вас или вложенный вами, = 10 очков; множитель — отношения и соседство). Страна вступает от 100 очков. Считается раз в месяц:"
		for entry: Dictionary in _info[&"influence"]:
			var item: TreeItem = _influence_tree.create_item(influence_root)
			_fill_influence_item(item, entry)
			item.set_text(6, String(entry[&"sphere_leader_tag"]))
			if int(entry[&"index"]) == _selected_influence:
				to_select = item
	else:
		_influence_caption.text = "Влияние великих держав на вашу страну (считается раз в месяц):"
		for entry: Dictionary in _info[&"influence_on_me"]:
			var item: TreeItem = _influence_tree.create_item(influence_root)
			_fill_influence_item(item, entry)
	if to_select != null:
		to_select.select(0)
	_update_invite()

	# the spheres of the world
	_spheres_tree.clear()
	var spheres_root: TreeItem = _spheres_tree.create_item()
	for sphere: Dictionary in _info[&"spheres"]:
		var item: TreeItem = _spheres_tree.create_item(spheres_root)
		item.set_text(0, sphere[&"leader_name"])
		item.set_metadata(0, sphere[&"leader_tag"])
		item.set_custom_bg_color(0, (sphere[&"colour"] as Color).lerp(Color.WHITE, 0.55))
		item.set_text(1, KIND_NAMES[int(sphere[&"kind"])])
		item.set_text(2, str((sphere[&"members"] as Array).size()))
		item.set_text(3, sphere[&"founded"])


func _fill_influence_item(item: TreeItem, entry: Dictionary) -> void:
	item.set_text(0, entry[&"name"])
	item.set_metadata(0, entry[&"tag"])
	item.set_metadata(1, int(entry[&"index"]))
	item.set_text(1, "%.0f" % float(entry[&"influence"]))
	item.set_text(2, "%.0f" % float(entry[&"trade"]))
	item.set_text(3, "%.0f" % float(entry[&"investment"]))
	item.set_text(4, "%+.0f %%" % (float(entry[&"multiplier"]) * 100.0))
	item.set_text(5, str(entry.get(&"relation", "")))


func _update_found() -> void:
	if _info.is_empty():
		return
	var kind: int = _found_kind.get_selected_id()
	var reasons: Array = _info[&"found_reasons"]
	var reason: String = reasons[kind] if kind >= 0 and kind < reasons.size() else ""
	_found_button.disabled = reason != ""
	_found_reason.text = KIND_DESCRIPTIONS[kind] if reason == "" else _reason(reason)


func _update_kind_change() -> void:
	if _info.is_empty() or not _info.get(&"is_leader", false):
		return
	var kind: int = _kind_option.get_selected_id()
	var reasons: Array = _info.get(&"kind_reasons", [])
	var reason: String = reasons[kind] if kind >= 0 and kind < reasons.size() else ""
	_kind_button.disabled = reason != ""
	if reason == "":
		_kind_reason.text = KIND_DESCRIPTIONS[kind]
	elif reason == "the kind was changed not long ago":
		_kind_reason.text = "Вид меняли недавно, снова можно с %s." % (_info[&"own"] as Dictionary).get(&"kind_change_date", "")
	else:
		_kind_reason.text = _reason(reason)


static func principle_name(principle: Dictionary) -> String:
	return PRINCIPLE_NAMES.get(String(principle[&"identifier"]), String(principle[&"identifier"]))


## What a principle gives at this bonus (0.05: 5 %)
static func principle_effect_text(principle: Dictionary, bonus: float) -> String:
	var percent: String = ("%.1f" % (bonus * 100.0)).trim_suffix(".0") + " %"
	match String(principle[&"effect"]):
		"output":
			if String(principle[&"identifier"]) == "military_industry":
				return "+%s выпуска военных заводов и РГО нефти, серы, каучука" % percent
			return "+%s выпуска товаров принципа" % percent
		"research":
			return "+%s к скорости исследований" % percent
		"literacy":
			return "+%s к росту грамотности" % percent
		"freight":
			return "−%s фрахта между странами сферы" % percent
		"loan_interest":
			return "−%s к процентам займов между странами сферы" % percent
		"militancy":
			return "−%s к росту воинственности" % percent
	return percent


func _refresh_principles(own: Dictionary, in_sphere: bool, is_leader: bool) -> void:
	_principles_caption.visible = in_sphere
	for row: HBoxContainer in _principle_rows:
		row.visible = in_sphere
	if not in_sphere:
		return
	var principles: Array = _info.get(&"principles", [])
	var slots: int = int(own.get(&"slots", 1))
	_principles_caption.text = "Принципы сферы — действуют на лидера и всех членов. Ячеек: %d из 3 (2 — от 3 стран, 3 — от 5). Уровень растёт сам: ×1.5 через 5 лет в ячейке, ×2 через 15; новый принцип начинает с уровня 1:" % slots
	var slot_entries: Array = own.get(&"principle_slots", [])
	for slot: int in 3:
		var entry: Dictionary = slot_entries[slot] if slot < slot_entries.size() else {}
		var principle_index: int = int(entry.get(&"principle", -1))
		var text: String
		if slot >= slots:
			text = "Ячейка %d: закрыта" % (slot + 1)
		elif principle_index < 0 or principle_index >= principles.size():
			text = "Ячейка %d: пусто" % (slot + 1)
		else:
			var principle: Dictionary = principles[principle_index]
			var level: int = int(entry[&"level"])
			text = "Ячейка %d: %s — %s (уровень %d)" % [slot + 1, principle_name(principle), principle_effect_text(principle, float(entry[&"bonus"])), level]
			if String(entry[&"next_level"]) != "":
				text += ", уровень %d с %s" % [level + 1, entry[&"next_level"]]
		_principle_status[slot].text = text
		_principle_option[slot].visible = is_leader and slot < slots
		_principle_button[slot].visible = is_leader and slot < slots
		_principle_reason[slot].visible = is_leader and slot < slots
		if is_leader and slot < slots:
			var option: OptionButton = _principle_option[slot]
			var selected_id: int = option.get_selected_id() if option.item_count > 0 else -2
			option.clear()
			option.add_item("— убрать —", -1)
			for principle: Dictionary in principles:
				option.add_item(principle_name(principle), int(principle[&"index"]))
			# the first free principle is offered, else what was selected
			var to_select: int = option.get_item_index(selected_id) if selected_id != -2 else -1
			if to_select < 0:
				to_select = 0
				var reasons: Array = (_info.get(&"principle_reasons", []) as Array)[slot]
				for principle: Dictionary in principles:
					if String(reasons[int(principle[&"index"])]) == "":
						to_select = option.get_item_index(int(principle[&"index"]))
						break
			option.select(to_select)
			_update_principle_row(slot)


func _update_principle_row(slot: int) -> void:
	var all_reasons: Array = _info.get(&"principle_reasons", [])
	if slot >= all_reasons.size():
		return
	var reasons: Array = all_reasons[slot]
	var principles: Array = _info.get(&"principles", [])
	var id: int = _principle_option[slot].get_selected_id()
	# the last reason is the one of emptying the slot
	var reason: String = String(reasons[reasons.size() - 1]) if id < 0 else String(reasons[id]) if id < reasons.size() else ""
	_principle_button[slot].disabled = reason != ""
	if reason != "":
		_principle_reason[slot].text = _reason(reason)
	elif id >= 0 and id < principles.size():
		_principle_reason[slot].text = principle_effect_text(principles[id], float(principles[id][&"value"]))
	else:
		_principle_reason[slot].text = "ячейка станет пустой"


func _on_principle_pressed(slot: int) -> void:
	PlayerSingleton.set_sphere_principle(slot, _principle_option[slot].get_selected_id())


func _find_influence(index: int) -> Dictionary:
	for entry: Dictionary in _info.get(&"influence", []):
		if int(entry[&"index"]) == index:
			return entry
	return {}


func _update_invite() -> void:
	var is_leader: bool = _info.get(&"is_leader", false)
	_invite_button.visible = is_leader
	_invite_reason.visible = is_leader
	if not is_leader:
		return
	var entry: Dictionary = _find_influence(_selected_influence)
	if entry.is_empty():
		_invite_button.disabled = true
		_invite_reason.text = "Выберите страну в списке влияния."
		return
	var reason: String = entry[&"invite_reason"]
	if reason != "":
		_invite_button.disabled = true
		_invite_reason.text = _reason(reason)
	elif not entry[&"accepts"]:
		_invite_button.disabled = true
		_invite_reason.text = "Не согласится: нужно влияние от 100 очков и отношения не ниже 0 (а у члена чужой сферы — на 50 очков больше влияния её лидера)."
	else:
		_invite_button.disabled = false
		_invite_reason.text = "%s согласится вступить." % entry[&"name"]


func _on_found_pressed() -> void:
	PlayerSingleton.found_sphere(_found_kind.get_selected_id())


func _on_influence_selected() -> void:
	var item: TreeItem = _influence_tree.get_selected()
	_selected_influence = item.get_metadata(1) if item != null and item.get_metadata(1) != null else -1
	_update_invite()


func _on_invite_pressed() -> void:
	if _selected_influence >= 0:
		PlayerSingleton.invite_to_sphere(_selected_influence)


func _on_country_activated(tree: Tree) -> void:
	var item: TreeItem = tree.get_selected()
	if item != null and item.get_metadata(0) is String:
		close()
		Events.NationManagementScreens.open_diplomacy_with(item.get_metadata(0))
