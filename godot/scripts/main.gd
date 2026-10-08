extends Control
## Native UI/controller. Rules, art, persistence, and optional account transport are separate.
const Model = preload("res://scripts/game_model.gd")
const Store = preload("res://scripts/save_store.gd")
const Accounts = preload("res://scripts/account_client.gd")
const SettlementWorld = preload("res://scripts/settlement_world.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Art = preload("res://scripts/pixel_art.gd")
const GOLD = Color("dcc08a")
const MUTED = Color("9aa8b8")
const TEXT = Color("e4e6df")
const TABS = ["Settlement","Expeditions","Loadout","Recruits","Treasury","Progression"]

var model = Model.new()
var store = Store.new()
var accounts: GraveholdAccountClient
var tab = "Settlement"
var selected_slot = ""
var panels: Dictionary = {}
var content: VBoxContainer
var resources: Dictionary = {}
var status_label: Label
var toast: Label
var nav_buttons: Dictionary = {}
var root_box: HBoxContainer
var scroll: ScrollContainer
var live_labels: Dictionary = {}
var world: Control
var settlement_position = Vector2(535,535)
var station_key = ""
var modal: AcceptDialog
var file_dialog: FileDialog
var import_mode = false
var focused = true
var autosave_elapsed = 0
var pending_ui_refresh = false
var account_message: Label
var guest_snapshot: Dictionary = {}
var demo_mode = false

func _ready() -> void:
 demo_mode = OS.get_cmdline_user_args().has("--demo")
 theme = make_theme()
 if demo_mode:
  store.path = "user://demo-save.json"
 var saved = store.read()
 if saved!=null:
  if not model.load_state(saved):
   push_warning("Save not loaded: "+model.last_error)
 restore_world_position()
 model.accrue()
 if demo_mode:
  prepare_demo()
 if not model.battle.is_empty():
  tab = "Expeditions"
 accounts = Accounts.new()
 add_child(accounts)
 accounts.status_changed.connect(_account_status)
 accounts.account_loaded.connect(_account_loaded)
 model.equipment_discovered.connect(func(item,wave):
  show_toast("%s FIND · %s · %s · wave %d" % [item.rarity.to_upper(),model.gear_item(item.slot,item.tier,item.upgrade).name,Model.stat_text(model.gear_item(item.slot,item.tier,item.upgrade).stats),wave]))
 model.expedition_finished.connect(func(): pending_ui_refresh = true)
 build_shell()
 render_tab()
 var second_timer = Timer.new()
 second_timer.wait_time = 1
 second_timer.timeout.connect(_second)
 add_child(second_timer)
 second_timer.start()
 var combat_timer = Timer.new()
 combat_timer.wait_time = .65
 combat_timer.timeout.connect(_combat)
 add_child(combat_timer)
 combat_timer.start()
 get_window().focus_entered.connect(func(): focused = true)
 get_window().focus_exited.connect(func(): focused = false)
 get_window().close_requested.connect(func(): save_progress(); get_tree().quit())
 save_progress()
 if not demo_mode and not model.s.tutorialsDisabled and not model.s.seen.has(tab):
  show_journal(tab)

func make_theme() -> Theme:
 var result = Theme.new()
 result.default_font_size = 14
 result.set_color("font_color","Label",TEXT)
 result.set_color("font_color","Button",TEXT)
 result.set_color("font_disabled_color","Button",Color("6c7784"))
 result.set_constant("separation","VBoxContainer",12)
 result.set_constant("separation","HBoxContainer",12)
 result.set_constant("h_separation","GridContainer",16)
 result.set_constant("v_separation","GridContainer",16)
 for type in ["normal","hover","pressed","disabled","focus"]:
  var color = Color("263242") if type=="normal" else Color("354351") if type=="hover" else Color("373b37") if type=="pressed" else Color("1c2531")
  var border = Color("ac9668") if type=="focus" or type=="pressed" else Color("465161")
  result.set_stylebox(type,"Button",style(color,border,7,10))
 result.set_stylebox("panel","PanelContainer",style(Color("1d2632"),Color("394553"),10,20))
 result.set_stylebox("panel","AcceptDialog",style(Color("1d2632"),GOLD,10,20))
 result.set_stylebox("normal","LineEdit",style(Color("121d29"),Color("43536a"),6,10))
 result.set_stylebox("focus","LineEdit",style(Color("121d29"),GOLD,6,10))
 result.set_color("font_color","LineEdit",TEXT)
 result.set_stylebox("background","ProgressBar",style(Color("111b26"),Color("354153"),4,0))
 result.set_stylebox("fill","ProgressBar",style(Color("a99466"),Color("a99466"),4,0))
 return result

func style(color: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
 var box = StyleBoxFlat.new()
 box.bg_color = color
 box.border_color = border
 box.set_border_width_all(1)
 box.set_corner_radius_all(radius)
 box.set_content_margin_all(margin)
 return box

func label(parent: Node, value: String, size_px: int = 14, color: Color = TEXT, wrap: bool = true) -> Label:
 var node = Label.new()
 node.text = value
 node.add_theme_font_size_override("font_size",size_px)
 node.add_theme_color_override("font_color",color)
 if wrap:
  node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 parent.add_child(node)
 return node

func button(parent: Node, value: String, action: String, disabled: bool = false, tooltip: String = "") -> Button:
 var node = Button.new()
 node.text = value
 node.name = action.replace(":","_")
 node.disabled = disabled
 node.tooltip_text = tooltip
 node.pressed.connect(func(): dispatch(action))
 parent.add_child(node)
 return node

func row(parent: Node, expand: bool = true) -> HBoxContainer:
 var node = HBoxContainer.new()
 if expand:
  node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 parent.add_child(node)
 return node

func card(parent: Node, title: String = "") -> VBoxContainer:
 var panel = PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 parent.add_child(panel)
 var box = VBoxContainer.new()
 box.add_theme_constant_override("separation",10)
 panel.add_child(box)
 if not title.is_empty():
  label(box,title,21,GOLD)
 return box

func disclosure(parent: Node, title: String, key: String) -> VBoxContainer:
 var panel = PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 parent.add_child(panel)
 var box = VBoxContainer.new()
 panel.add_child(box)
 var toggle = Button.new()
 toggle.name = "panel_"+key
 toggle.text = ("▾ " if panels.get(key,false) else "▸ ")+title
 toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
 toggle.add_theme_stylebox_override("normal",style(Color("1d2632"),Color("1d2632"),0,0))
 box.add_child(toggle)
 var detail = VBoxContainer.new()
 detail.visible = panels.get(key,false)
 box.add_child(detail)
 toggle.pressed.connect(func():
  panels[key] = not panels.get(key,false)
  detail.visible = panels[key]
  toggle.text = ("▾ " if detail.visible else "▸ ")+title)
 return detail

func progress(parent: Node, value: float, maximum: float = 100) -> ProgressBar:
 var bar = ProgressBar.new()
 bar.value = value
 bar.max_value = maximum
 bar.show_percentage = false
 bar.custom_minimum_size = Vector2(0,6)
 parent.add_child(bar)
 return bar

func portrait(parent: Node, kind: String, dimensions: Vector2 = Vector2(80,100)) -> TextureRect:
 var image = TextureRect.new()
 image.texture = Art.character(kind,model)
 image.custom_minimum_size = dimensions
 image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 image.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(image)
 return image

func build_shell() -> void:
 root_box = HBoxContainer.new()
 root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root_box.add_theme_constant_override("separation",0)
 add_child(root_box)
 var aside = PanelContainer.new()
 aside.custom_minimum_size = Vector2(195,0)
 aside.add_theme_stylebox_override("panel",style(Color("101924"),Color("2c3848"),0,20))
 root_box.add_child(aside)
 var nav = VBoxContainer.new()
 aside.add_child(nav)
 label(nav,"✧ GRAVEHOLD",23,GOLD,false)
 label(nav,"FROM ASHES, A KINGDOM",9,MUTED,false)
 var space = Control.new()
 space.custom_minimum_size.y = 35
 nav.add_child(space)
 for title in TABS:
  var b = button(nav,title,"tab:"+title)
  b.alignment = HORIZONTAL_ALIGNMENT_LEFT
  nav_buttons[title] = b
 var spacer = Control.new()
 spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
 nav.add_child(spacer)
 label(nav,"The darkness waits.\nBuild something that lasts.",12,MUTED)
 button(nav,"Save settings","settings")
 var main_margin = MarginContainer.new()
 for side in ["left","right","top","bottom"]:
  main_margin.add_theme_constant_override("margin_"+side,24)
 main_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 root_box.add_child(main_margin)
 var main = VBoxContainer.new()
 main_margin.add_child(main)
 var top = row(main)
 for key in ["wood","stone","food","gold"]:
  var box = VBoxContainer.new()
  box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  box.add_theme_constant_override("separation",2)
  top.add_child(box)
  var amount = label(box,"",15,GOLD)
  var income = label(box,"",10,MUTED)
  amount.mouse_filter = Control.MOUSE_FILTER_STOP
  income.mouse_filter = Control.MOUSE_FILTER_STOP
  resources[key] = {"amount":amount,"income":income}
 button(top,"Inventory","inventory")
 button(top,"Journal","journal")
 button(top,"Account","account")
 main.add_child(HSeparator.new())
 toast = label(main,"",12,GOLD)
 toast.visible = false
 var header = label(main,tab,30,TEXT)
 header.name = "PageTitle"
 scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 main.add_child(scroll)
 content = VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation",18)
 scroll.add_child(content)
 status_label = label(main,"LOCAL SAVE",10,MUTED)
 update_resources()

func render_tab() -> void:
 if world is GraveholdSettlementWorld:
  settlement_position = world.hero_position
 var old_scroll = scroll.scroll_vertical
 for child in content.get_children():
  content.remove_child(child)
  child.queue_free()
 live_labels.clear()
 world = null
 for title in nav_buttons:
  nav_buttons[title].visible = title in ["Settlement","Expeditions","Loadout"] or tab!="Settlement"
  nav_buttons[title].add_theme_color_override("font_color",GOLD if title==tab else TEXT)
 var page_title = root_box.find_child("PageTitle",true,false)
 page_title.text = "Your settlement" if tab=="Settlement" else tab
 match tab:
  "Settlement": settlement_ui()
  "Expeditions": expeditions_ui()
  "Loadout": loadout_ui()
  "Recruits": recruits_ui()
  "Treasury": treasury_ui()
  "Progression": progression_ui()
 scroll.set_deferred("scroll_vertical",old_scroll)
 update_resources()

func update_resources() -> void:
 for key in resources:
  var amount = int(model.s[key])
  resources[key].amount.text = "%d / %d" % [amount,model.cap(key)] if key!="gold" else str(amount)
  resources[key].income.text = key.to_upper()+ (" · FULL" if key!="gold" and amount>=model.cap(key) else " · +%.1f/s" % model.income_rate(key) if key!="gold" else "")
  var tooltip = Model.RESOURCE_HELP[key]
  if key!="gold":
   tooltip += "\nOnline %.2f/sec · offline %.2f/sec\nStorage %d/%d" % [model.income_rate(key),model.income_rate(key)*.5,amount,model.cap(key)]
   if amount>=model.cap(key)*.9:
    tooltip += "\nStorage nearly full. Upgrade to avoid waste."
    resources[key].amount.add_theme_color_override("font_color",Color("e3a181"))
   else:
    resources[key].amount.add_theme_color_override("font_color",GOLD)
  resources[key].amount.tooltip_text = tooltip
  resources[key].income.tooltip_text = tooltip
 if status_label!=null:
  status_label.text = accounts.sync_status+ (" · "+accounts.email if not accounts.email.is_empty() else " · SAVED ON THIS COMPUTER")+ (" · "+str(model.s.log[0]) if not model.s.log.is_empty() else "")
 for key in live_labels:
  var node = live_labels[key]
  if not is_instance_valid(node):
   continue
  if key.begins_with("stockbar_"):
   var kind = key.trim_prefix("stockbar_")
   node.value = model.s[kind]
  elif key.begins_with("stock_"):
   var kind = key.trim_prefix("stock_")
   node.text = "%.2f/sec · %d / %d stored" % [model.income_rate(kind),model.s[kind],model.cap(kind)]
  elif key.begins_with("gather_"):
   var kind = key.trim_prefix("gather_")
   if model.s.gather!=null and model.s.gather.kind==kind:
    var left = maxf(0,(model.s.gather.end-Model.now_ms())/1000.0)
    node.text = "Collect +%d" % model.s.gather.amount if left<=0 else "Gathering… %ds" % ceil(left)
    node.disabled = left>0
   else:
    node.text = "Gather "+kind
    node.disabled = model.s.gather!=null
  elif key=="recover":
   node.text = "Recovering · %ds" % maxf(0,ceil((model.s.recover-Model.now_ms())/1000)) if model.s.recover>0 else "Free recovery · 5 minutes"
  elif key=="queue_status" and model.s.offlineQueue!=null:
   node.text = "%s · %d queued · next return in %ds" % [model.s.offlineQueue.dungeon.name,model.s.offlineQueue.remaining,maxf(0,ceil((model.s.offlineQueue.readyAt-Model.now_ms())/1000))]
 if world!=null and is_instance_valid(world):
  world.queue_redraw()

func availability_signature() -> String:
 var flags: Array = []
 var costs: Array = [{"wood":20,"stone":10},{"wood":20,"food":15},Model.BARRACKS_COST,{"wood":300,"stone":200,"food":250},{"wood":300,"stone":250,"gold":150},{"gold":20,"food":25},{"gold":20},model.recruit_cost(),model.revive_cost()]
 for key in Model.RESOURCES:
  costs.append(model.storage_cost(key))
  flags.append(model.s[key]>=model.cap(key)*.9)
  if model.s.workers.has(key):
   var level = floori(model.s.workers[key].xp/300.0)
   flags.append(level)
   costs.append({key:30+level*15})
 for cost in costs: flags.append(model.can_pay(cost))
 for key in Model.SLOTS:
  flags.append(model.can_pay(model.upgrade_cost(key),true))
  flags.append(model.can_pay(model.forge_cost(key),true))
 for recruit in model.s.recruits: flags.append(model.can_pay(model.revive_cost(recruit)))
 return JSON.stringify(flags)

func _second() -> void:
 var old_availability = availability_signature()
 var old_gather = model.s.gather!=null
 var old_dead = model.s.heroDead
 var old_runs = model.s.expeditions
 var online = focused or (modal!=null and is_instance_valid(modal) and modal.visible and modal.has_focus()) or (file_dialog!=null and is_instance_valid(file_dialog) and file_dialog.visible and file_dialog.has_focus())
 model.accrue(-1,online)
 if old_availability!=availability_signature() or old_gather!=(model.s.gather!=null) or old_dead!=model.s.heroDead or old_runs!=model.s.expeditions:
  render_tab()
  if modal!=null and is_instance_valid(modal) and modal.visible and modal.title=="Settlement interaction": open_station(station_key)
 update_resources()
 autosave_elapsed += 1
 if autosave_elapsed>=5:
  autosave_elapsed = 0
  save_progress()
 if model.s.lootAlert!=null and Model.now_ms()>model.s.lootAlert.until:
  toast.visible = false

func _combat() -> void:
 if not focused:
  return
 if not model.battle.is_empty():
  var old_phase = model.battle.phase
  var old_wave = model.battle.wave
  model.tick_battle()
  if model.battle.is_empty() or old_phase!=model.battle.phase or old_wave!=model.battle.wave:
   render_tab()
  else:
   update_battle_text()
  if pending_ui_refresh:
   pending_ui_refresh = false
   save_progress()
  update_resources()

func restore_world_position() -> void:
 var point = model.s.get("settlementPosition",[535,535])
 if point is Array and point.size()==2 and (point[0] is int or point[0] is float) and (point[1] is int or point[1] is float) and is_finite(float(point[0])) and is_finite(float(point[1])):
  settlement_position = Vector2(point[0],point[1]).clamp(Vector2(35,85),Vector2(1065,610))
 else: settlement_position = Vector2(535,535)
 if world is GraveholdSettlementWorld: world.hero_position = settlement_position

func save_progress() -> void:
 if world is GraveholdSettlementWorld:
  settlement_position = world.hero_position
 model.s["settlementPosition"] = [settlement_position.x,settlement_position.y]
 if not store.write(model.serialize()):
  show_toast(store.last_error)
 if not accounts.email.is_empty():
  accounts.sync(model.serialize())

func show_toast(message: String) -> void:
 if toast!=null:
  toast.text = message
  toast.visible = true

func dispatch(action: String) -> void:
 var parts = action.split(":",false,1)
 var kind = parts[0]
 var key = parts[1] if parts.size()>1 else ""
 var ok = true
 match kind:
  "tab":
   if not model.battle.is_empty() and key!="Expeditions":
    show_toast("Finish or extract before leaving the expedition.")
    return
   tab = key
   scroll.scroll_vertical = 0
   render_tab()
   if not model.s.tutorialsDisabled and not model.s.seen.has(tab):
    show_journal(tab)
   return
  "world_loadout":
   modal.hide()
   dispatch("tab:Loadout")
   return
  "journal": show_journal(tab); return
  "inventory": inventory_dialog(); return
  "settings": settings_dialog(); return
  "account": account_dialog(); return
  "slot": selected_slot = key; render_tab(); return
  "focus":
   if not model.locked(): model.s.rewardFocus = key
  "objective":
   if not model.locked(): model.s.objective = key
  "gather": ok = model.collect_gather() if model.s.gather!=null and model.s.gather.kind==key else model.start_gather(key)
  "build": ok = model.build_site(key)
  "worker": ok = model.hire_worker(key)
  "train": ok = model.train_worker(key)
  "storage": ok = model.upgrade_storage(key)
  "barracks": ok = model.build_barracks()
  "foreman": ok = model.hire_foreman()
  "recruit": ok = model.hire_recruit(key)
  "revive": ok = model.revive_recruit(int(key))
  "enter": ok = model.enter_dungeon(int(key))
  "continue": ok = model.continue_battle()
  "extract": ok = model.extract()
  "equip":
   var index = int(key)
   if index>=0 and index<model.s.equipmentBag.size(): selected_slot = model.s.equipmentBag[index].slot
   ok = model.equip_item(index)
  "dismiss": ok = model.dismiss_item(int(key))
  "salvage": confirm_salvage(int(key)); return
  "upgrade": ok = model.upgrade_item(key)
  "craft": ok = model.forge_item(key)
  "hero": ok = model.revive_hero()
  "loan": ok = model.revive_hero(true)
  "recover": ok = model.begin_recovery()
  "repay": ok = model.repay()
  "talent": ok = model.buy_talent(key)
  "prestige": confirm_prestige(); return
  "queue": ok = model.start_queue(key,1)
  "queue3": ok = model.start_queue(key,3)
  "specialist": ok = model.specialist_service(key)
  "import": choose_save_file(true); return
  "export": choose_save_file(false); return
  "reset": confirm_reset(); return
  "fullscreen":
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
   return
  _:
   return
 if not ok:
  show_toast(model.last_error if not model.last_error.is_empty() else "This action is not available yet. Check resources and requirements.")
 save_progress()
 render_tab()
 if modal!=null and is_instance_valid(modal) and modal.visible:
  if modal.title=="Inventory": inventory_dialog()
  elif modal.title=="Settlement interaction": open_station(station_key)

func settlement_ui() -> void:
 world = SettlementWorld.new()
 world.model = model
 world.hero_position = settlement_position
 world.can_move = func(): return focused and (modal==null or not is_instance_valid(modal) or not modal.visible) and (file_dialog==null or not is_instance_valid(file_dialog) or not file_dialog.visible)
 world.interacted.connect(open_station)
 content.add_child(world)
 label(content,"Walk to a site and press E. Click a building to approach it. Visit the gate for expeditions, the blacksmith for equipment, and the barracks for companions.",12,MUTED)

func open_station(key: String) -> void:
 if key=="gate":
  if modal!=null and is_instance_valid(modal): modal.hide()
  dispatch("tab:Expeditions")
  return
 station_key = key
 var box = open_dialog("Settlement interaction")
 label(box,SettlementWorld.STATIONS[key].name,24,GOLD)
 if key in Model.RESOURCES:
  var titles = {"wood":"Woodcutting camp","stone":"Stone quarry","food":"Homestead"}
  var jobs = {"wood":"woodcutter","stone":"miner","food":"farmer"}
  var site = card(box,titles[key])
  live_labels["stock_"+key] = label(site,"",12,MUTED)
  live_labels["stockbar_"+key] = progress(site,model.s[key],model.cap(key))
  var gather = button(site,"Gather "+key,"gather:"+key)
  live_labels["gather_"+key] = gather
  label(site,"Manual yield +%d · 8 seconds" % model.gather_yield(key),11,MUTED)
  if not model.s.buildings.has(key):
   button(site,"Build site · 20 wood · 10 stone","build:"+key,not model.can_pay({"wood":20,"stone":10}))
  elif not model.s.workers.has(key):
   label(site,"VACANT POSITION",10,GOLD)
   button(site,"Hire "+jobs[key]+" · 20 wood · 15 food","worker:"+key,not model.can_pay({"wood":20,"food":15}),"+1 resource/sec · +4 manual yield · hero settlement bonus")
  else:
   label(site,"Worker level %d" % (1+floori(model.s.workers[key].xp/300.0)),12,GOLD)
   var training = disclosure(site,"Worker training","training_"+key)
   var cost = 30+floori(model.s.workers[key].xp/300.0)*15
   label(training,"Income %.2f → %.2f/sec · manual yield +4" % [model.income_rate(key),model.income_rate(key)+.2*(1+model.s.meta.prestiges*.05)],11,MUTED)
   button(training,"Train · %d %s" % [cost,key],"train:"+key,model.s[key]<cost)
  var storage_detail = disclosure(site,"Storage · %d capacity" % model.cap(key),"storage_"+key)
  var cost = model.storage_cost(key)
  label(storage_detail,"Capacity %d → %d · manual yield +4\n%s" % [model.cap(key),model.cap(key)+150,Model.cost_text(cost)],11,MUTED)
  button(storage_detail,"Upgrade storage","storage:"+key,not model.can_pay(cost))
  if model.s[key]>=model.cap(key)*.9:
   label(site,"Storage nearly full. Upgrade to avoid waste.",11,Color("e3a181"))
 elif key=="barracks":
  if not model.s.buildings.has("barracks"):
   support_ui(box)
  else:
   var previous = content
   content = box
   recruits_ui()
   content = previous
 elif key=="forge":
  label(box,"Inspect your equipment and choose a slot to upgrade or forge. A rescued blacksmith can establish a workshop for a 10% gold discount on upgrades.",13,MUTED)
  button(box,"Open equipment","world_loadout")
  var previous = content
  content = box
  specialists_ui()
  content = previous
 elif key=="treasury":
  var previous = content
  content = box
  treasury_ui()
  specialists_ui()
  content = previous
 elif key=="camp":
  label(box,"Rest by the fire, plan your legacy, and manage camp help.",13,MUTED)
  if model.s.foreman:
   label(box,"Camp Foreman automatically collects completed gathering tasks.",12,GOLD)
  else:
   button(box,"Hire Foreman · 300 wood · 200 stone · 250 food","foreman",model.s.workers.size()<3 or not model.can_pay({"wood":300,"stone":200,"food":250}))
  var previous = content
  content = box
  progression_ui()
  content = previous
 update_resources()
 popup_dialog()

func support_ui(parent: Node) -> void:
 label(parent,"Woodcutter +1 hero attack · Miner +1 defense · Farmer +5 HP",12,GOLD)
 if model.s.buildings.has("barracks"):
  label(parent,"Barracks ready. Dungeon gold and settlement supplies fund companions.",12,MUTED)
 else:
  label(parent,"Barracks requires all three workers and wave five reached.\n"+Model.cost_text(Model.BARRACKS_COST),12,MUTED)
  button(parent,"Establish barracks","barracks",not model.barracks_ready() or not model.can_pay(Model.BARRACKS_COST))

func specialists_ui() -> void:
 var detail = disclosure(content,"Settlement specialists · %d / 3 rescued" % model.s.specialists.size(),"specialists")
 label(detail,"Wave 10: 8% rescue chance. A final boss frees one missing resident. Extract to bring them home. Offline queues do not rescue specialists.",12,MUTED)
 var grid = GridContainer.new()
 grid.columns = 3
 detail.add_child(grid)
 for key in Model.SPECIALISTS:
  if not model.s.specialists.get(key,false): continue
  var info = Model.SPECIALISTS[key]
  var box = card(grid,info.name)
  portrait(box,"Miner" if key=="blacksmith" else "Farmer" if key=="quartermaster" else "Archer",Vector2(48,60))
  label(box,info.role.to_upper(),10,GOLD)
  label(box,info.help,12,MUTED)
  var disabled = model.locked()
  var action_text = ""
  if key=="blacksmith":
   disabled = disabled or model.s.buildings.has("workshop") or not model.can_pay(Model.WORKSHOP_COST)
   action_text = "Workshop ready" if model.s.buildings.has("workshop") else "Build workshop · "+Model.cost_text(Model.WORKSHOP_COST)
  elif key=="quartermaster":
   disabled = disabled or model.s.quartermasterRun==model.s.expeditions or model.s.food+25>model.cap("food") or model.s.gold<20
   action_text = "Buy 25 food · 20 gold"
  else:
   disabled = disabled or model.s.gold<20
   action_text = "Survey routes · 20 gold"
  button(box,action_text,"specialist:"+key,disabled)
 if model.s.specialists.is_empty(): label(detail,"No residents rescued yet.",12,MUTED)

func expeditions_ui() -> void:
 if not model.battle.is_empty():
  battle_ui()
  return
 if not model.gates_open():
  label(content,"Build a production site in Settlement to unlock dungeons.",16,GOLD)
  return
 label(content,"Choose your descent",24,TEXT)
 var focus = row(content)
 label(focus,"Reward focus",12,MUTED,false)
 for key in ["balanced","gold","materials","equipment"]:
  var b = button(focus,{"balanced":"Balanced","gold":"Gold +60%","materials":"Materials ×2","equipment":"Gear chance +75%"}[key],"focus:"+key,model.locked())
  if model.s.rewardFocus==key: b.add_theme_color_override("font_color",GOLD)
 label(content,"15 waves · extract every 5 · equipment chance capped at 18%",11,MUTED)
 var objective = disclosure(content,"Optional objective · "+Model.OBJECTIVES[model.s.objective].name,"objective")
 var objective_buttons = row(objective)
 for key in Model.OBJECTIVES:
  var b = button(objective_buttons,Model.OBJECTIVES[key].name,"objective:"+key,model.locked())
  if model.s.objective==key: b.add_theme_color_override("font_color",GOLD)
 var info = Model.OBJECTIVES[model.s.objective]
 label(objective,info.help+ (" Bonus: "+Model.cost_text(info.reward) if not info.reward.is_empty() else "")+"\nOne fixed bonus on extraction. No multipliers or offline objectives.",12,MUTED)
 var grid = GridContainer.new()
 grid.columns = 3
 content.add_child(grid)
 var options = model.choices()
 for i in range(3):
  var c = options[i]
  var box = card(grid,c.name)
  label(box,["EASY","MEDIUM","HARD"][i],10,GOLD)
  var risk = model.forecast(c)
  label(box,"Full clear chance · %d%%" % risk,15,TEXT)
  progress(box,risk)
  label(box,Model.MODIFIERS[c.modifier]+" · Loot ×"+str((i+1)*(2 if c.modifier=="double" else 1)),12,MUTED)
  button(box,"Enter dungeon →","enter:"+str(i),model.s.heroDead or model.locked())
 if model.s.heroDead:
  label(content,"Your hero needs revival in the Treasury.",14,Color("e3a181"))
 elif model.s.offlineQueue!=null:
  label(content,"Your hero is away on a queued expedition.",14,GOLD)
 var support = disclosure(content,"Settlement support","expedition_support")
 support_ui(support)
 history_ui(content)
 queue_ui()
 if model.s.lastExpedition!=null:
  var result = model.s.lastExpedition
  var previous = disclosure(content,"Last expedition · wave %d · %s" % [result.wave,"rewards secured" if result.won else "defeated"],"last_result")
  report_ui(previous,result.get("report"))
  if result.won:
   if result.get("objective")!=null: label(previous,"Objective complete · "+result.objective,12,GOLD)
   if result.get("rescue")!=null: label(previous,Model.SPECIALISTS[result.rescue].name+" arrived in the settlement.",12,GOLD)
   spoils_ui(previous,result.loot,true)
  else:
   label(previous,"Unsecured rewards were lost.",12,MUTED)

func battle_ui() -> void:
 var b = model.battle
 var header = row(content)
 label(header,b.name,25,TEXT)
 live_labels.wave = label(header,"Wave %d / 15" % b.wave,20,GOLD,false)
 label(content,["Easy","Medium","Hard"][int(b.d)]+" · "+Model.MODIFIERS[b.get("modifier","none")]+" · "+b.get("focus","balanced")+" rewards",12,MUTED)
 var track = row(content)
 for i in range(15):
  var segment = ColorRect.new()
  segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  segment.custom_minimum_size = Vector2(0,8 if (i+1)%5==0 else 5)
  segment.color = GOLD if i+1==b.wave else Color("748c71") if i+1<b.wave else Color("344152")
  track.add_child(segment)
 world = WorldView.new()
 world.mode = "battle"
 world.model = model
 content.add_child(world)
 live_labels.caption = label(content,str(b.events[0]),12,MUTED)
 if b.checkpoint:
  var checkpoint = row(content)
  label(checkpoint,"Checkpoint · continuing restores 20% HP to survivors",12,GOLD)
  button(checkpoint,"Extract loot","extract")
  button(checkpoint,"Continue →","continue")
 if b.get("objective","none")!="none":
  label(content,Model.OBJECTIVES[b.objective].name+" · "+("Ready to claim on extraction" if model.objective_complete() else Model.OBJECTIVES[b.objective].help),12,GOLD)
 if b.has("rescue"):
  label(content,Model.SPECIALISTS[b.rescue].name+" freed · extract safely to bring them home",12,GOLD)
 spoils_ui(content,b.loot,false)
 var log_box = disclosure(content,"Battle log","combat_log")
 live_labels.combat_log = label(log_box,"\n".join(PackedStringArray(b.events)),12,MUTED)

func update_battle_text() -> void:
 if model.battle.is_empty(): return
 if live_labels.has("caption"): live_labels.caption.text = model.battle.events[0]
 if live_labels.has("combat_log"): live_labels.combat_log.text = "\n".join(PackedStringArray(model.battle.events))
 if world!=null: world.queue_redraw()

func spoils_ui(parent: Node, loot: Dictionary, secured: bool) -> void:
 var box = card(parent,"Brought home" if secured else "Dungeon spoils · at risk until extraction")
 label(box,"%d GOLD" % loot.get("gold",0),22,GOLD)
 var counts = row(box)
 for key in Model.MATERIALS+["blueprints"]:
  label(counts,key.capitalize()+"\n"+str(loot.get(key,0)),12,MUTED)
 for item in loot.get("equipment",[]):
  var r = row(box)
  var icon = TextureRect.new()
  icon.texture = Art.item(item.slot,int(item.tier),item.get("rarity","common"))
  icon.custom_minimum_size = Vector2(40,40)
  icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  r.add_child(icon)
  label(r,model.gear_item(item.slot,int(item.tier),int(item.get("upgrade",0))).name+" · "+item.get("rarity","common").capitalize(),14,Art.RARITY_COLORS.get(item.get("rarity","common"),GOLD))
 var supplies = disclosure(box,"Settlement supplies","supplies")
 label(supplies,"Wood %d · Stone %d · Food %d" % [loot.get("wood",0),loot.get("stone",0),loot.get("food",0)],12,MUTED)

func report_ui(parent: Node, report: Variant) -> void:
 if not report is Dictionary: return
 var box = card(parent,"Expedition debrief")
 var support = 0
 for key in report.damage:
  if key!="hero": support += report.damage[key]
 var healing = 0
 for value in report.healing.values(): healing += value
 label(box,"Hero damage %d · Support %d · Healing %d · Received %d" % [report.damage.get("hero",0),support,healing,report.taken],14,GOLD)
 if not report.get("won",false) and report.get("lastHit")!=null:
  label(box,"Defeated by %s · %d final damage" % [report.lastHit.name,report.lastHit.damage],12,Color("e3a181"))
 label(box,report.get("recommendation","Improve your loadout before returning."),12,MUTED)
 var detail = disclosure(box,"Individual contributions","contributions")
 var ids = report.damage.keys()
 for key in report.healing:
  if not ids.has(key): ids.append(key)
 for key in ids:
  var display_name = report.get("names",{}).get(key,"Hero" if key=="hero" else "Companion")
  label(detail,"%s · %d damage · %d healing" % [display_name,report.damage.get(key,0),report.healing.get(key,0)],12,MUTED)

func history_ui(parent: Node) -> void:
 var h = model.s.history
 var detail = disclosure(parent,"Expedition history · %d runs · best wave %d" % [h.runs,h.best],"history")
 label(detail,"Total runs %d · Best wave %d · Bosses %d · Secured gold %d" % [h.runs,h.best,h.bosses,h.gold],14,GOLD)
 for run in h.recent:
  label(detail,"%s · wave %d · %s" % [run.name,run.wave,"returned with %d gold" % run.gold if run.won else "defeated"],12,MUTED)

func queue_ui() -> void:
 var detail = disclosure(content,"Offline expeditions","queue")
 label(detail,"Previously cleared routes only. Five minutes/run, 50% rewards, up to three runs. Defeat stops the queue. No objectives or rescues.",12,MUTED)
 if model.s.offlineQueue!=null:
  live_labels.queue_status = label(detail,"",14,GOLD)
 else:
  if model.s.clearedDungeons.is_empty(): label(detail,"Defeat a final boss to unlock a route.",12,MUTED)
  for key in model.s.clearedDungeons:
   var r = row(detail)
   label(r,model.s.clearedDungeons[key].name,14,TEXT)
   button(r,"Send 1 run","queue:"+str(key),model.s.heroDead or model.locked())
   button(r,"Send 3 runs","queue3:"+str(key),model.s.heroDead or model.locked())

func loadout_ui() -> void:
 var strip = row(content)
 strip.add_theme_constant_override("separation",18)
 var recent = card(strip,"New finds")
 recent.get_parent().size_flags_vertical = Control.SIZE_SHRINK_BEGIN
 recent.get_parent().custom_minimum_size.x = 240
 recent.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var indexes = []
 for i in range(model.s.equipmentBag.size()-1,-1,-1):
  if model.s.equipmentBag[i].get("newFind",true): indexes.append(i)
  if indexes.size()==5: break
 if indexes.is_empty(): label(recent,"No new finds. Extract with equipment to fill this list.",12,MUTED)
 for index in indexes: item_row(recent,index,true)
 var equipment = card(strip,"Equipment · %d / 10" % Model.SLOTS.filter(func(k): return model.s.gear[k]>=0).size())
 equipment.get_parent().size_flags_stretch_ratio = 1.5
 equipment.get_parent().custom_minimum_size.x = 355
 var centered = CenterContainer.new()
 equipment.add_child(centered)
 var board = Control.new()
 board.custom_minimum_size = Vector2(298,420)
 centered.add_child(board)
 var positions = {"head":Vector2(1,0),"cape":Vector2(0,1),"neck":Vector2(2,1),"weapon":Vector2(0,2),"body":Vector2(2,2),"shield":Vector2(0,3),"legs":Vector2(2,3),"hands":Vector2(0,4),"feet":Vector2(1,4),"ring":Vector2(2,4)}
 for key in Model.SLOTS:
  var item = model.gear_item(key)
  var slot_button = button(board,key.capitalize(),"slot:"+key,false,item.get("name","Empty "+key))
  slot_button.position = positions[key]*Vector2(102,84)
  slot_button.size = Vector2(94,76)
  slot_button.icon = Art.item(key,int(model.s.gear[key]),model.s.gearRarities[key])
  slot_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  slot_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
  slot_button.expand_icon = true
  slot_button.add_theme_constant_override("icon_max_width",36)
  slot_button.add_theme_font_size_override("font_size",11)
  slot_button.add_theme_color_override("font_color",Art.RARITY_COLORS.get(model.s.gearRarities[key],MUTED) if not item.is_empty() else MUTED)
  if selected_slot==key:
   slot_button.add_theme_stylebox_override("normal",style(Color("393a35"),GOLD,8,7))
 var hero = portrait(board,"hero",Vector2(110,138))
 hero.position = Vector2(95,174)
 hero.size = Vector2(110,138)
 var name_label = label(board,"THE WARDEN",9,GOLD,false)
 name_label.position = Vector2(115,316)
 var stats = model.hero_stats()
 label(equipment,"Attack %d · Defense %.2f · HP %d" % [stats.attack,stats.defense,stats.health],18,GOLD)
 var sets = Model.SLOTS.filter(func(k): return model.s.gear[k]==2).size()
 label(equipment,"Gravewarden set · %d / 3 · %s" % [sets,"+10% HP active" if sets>=3 else "3 pieces grant +10% HP"],11,MUTED)
 var bonuses = disclosure(equipment,"Combat bonuses","bonuses")
 label(bonuses,"Crit %d%% · Evasion %d%% · Life steal %d%%" % [roundi(stats.crit*100),roundi(stats.evade*100),roundi(stats.leech*100)],12,MUTED)
 var available = card(strip,"Available equipment")
 available.get_parent().size_flags_vertical = Control.SIZE_SHRINK_BEGIN
 available.get_parent().custom_minimum_size.x = 240
 if selected_slot.is_empty():
  label(available,"Select a hero slot to compare items.",12,MUTED)
 else:
  var options = model.ranked_items(selected_slot)
  label(available,selected_slot.capitalize()+" slot · combat gains first",11,MUTED)
  if options.is_empty(): label(available,"No spare items for this slot yet.",12,MUTED)
  for option in options: item_row(available,option.index,false)
  selected_item_ui()

func item_row(parent: Node, index: int, recent: bool) -> void:
 var item = model.s.equipmentBag[index]
 var info = model.gear_item(item.slot,int(item.tier),int(item.get("upgrade",0)))
 var box = VBoxContainer.new()
 box.add_theme_constant_override("separation",6)
 parent.add_child(box)
 box.add_child(HSeparator.new())
 var inspect = button(box,info.name,"slot:"+item.slot,false,Model.stat_text(info.stats))
 inspect.icon = Art.item(item.slot,int(item.tier),item.rarity)
 inspect.expand_icon = true
 inspect.add_theme_constant_override("icon_max_width",32)
 inspect.add_theme_font_size_override("font_size",12)
 inspect.add_theme_color_override("font_color",Art.RARITY_COLORS.get(item.rarity,GOLD))
 label(box,item.rarity.capitalize()+" · "+item.slot.capitalize(),10,MUTED)
 var delta = model.item_comparison(item)
 label(box,Model.stat_text(delta,true),11,Color("a6c69f") if Model.item_score(delta)>0 else Color("dda09c") if Model.item_score(delta)<0 else MUTED)
 var actions = row(box)
 for action in ["equip","salvage"]+( ["dismiss"] if recent else []):
  var b = button(actions,action.capitalize(),action+":"+str(index),model.locked() if action!="dismiss" else false)
  b.add_theme_font_size_override("font_size",11)
  b.add_theme_stylebox_override("normal",style(Color("263242"),Color("465161"),5,7))

func selected_item_ui() -> void:
 var item = model.gear_item(selected_slot)
 var box = card(content,selected_slot.capitalize()+" · "+item.get("name","Empty slot"))
 if item.is_empty():
  label(box,"Find a piece at five-wave milestones. Available equipment is shown on the right.",12,MUTED)
  return
 label(box,Model.stat_text(item.stats),14,GOLD)
 var actions = row(box)
 var upgrade = model.upgrade_cost(selected_slot)
 var forge = model.forge_cost(selected_slot)
 var upgrade_box = VBoxContainer.new()
 upgrade_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 actions.add_child(upgrade_box)
 button(upgrade_box,"Upgrade · "+Model.cost_text(upgrade),"upgrade:"+selected_slot,model.locked() or not model.can_pay(upgrade,true))
 label(upgrade_box,"After: "+Model.stat_text(model.gear_item(selected_slot,int(item.tier),int(item.upgrade)+1).stats),11,MUTED)
 var forge_box = VBoxContainer.new()
 forge_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 actions.add_child(forge_box)
 button(forge_box,"Forge next tier · 1 blueprint","craft:"+selected_slot,model.locked() or model.s.blueprints<1 or not model.can_pay(forge,true))
 label(forge_box,Model.cost_text(forge)+"\nNext tier: "+Model.stat_text(model.gear_item(selected_slot,int(item.tier)+1,0).stats),11,MUTED)

func recruits_ui() -> void:
 label(content,"Your companions · %d / 3" % model.s.recruits.size(),24,TEXT)
 var grid = GridContainer.new()
 grid.columns = 3
 content.add_child(grid)
 if model.s.recruits.is_empty(): label(content,"Build the barracks to welcome your first companion.",14,MUTED)
 for index in range(model.s.recruits.size()):
  var r = model.s.recruits[index]
  var unit = model.recruit_unit(r,index)
  var box = card(grid,r.name)
  portrait(box,r.cls)
  label(box,"%s · LEVEL %d" % [r.cls.to_upper(),r.level],10,GOLD)
  label(box,"HP %d · Attack %d · Defense %d" % [unit.maxHp,unit.attack,unit.defense],13,TEXT)
  var healing = 3+floori(r.level/4.0)+(1 if r.level>=5 else 0)
  label(box,"%d healing/cast" % healing if r.cls=="Healer" else "%d%% personal crit" % roundi(unit.crit*100),12,MUTED)
  progress(box,r.xp,20)
  label(box,"%d / 20 expeditions to level %d" % [r.xp,r.level+1],11,MUTED)
  label(box,"Next: +2 HP"+(" · +1 attack" if (int(r.level)+1)%4==0 else "")+(" · +1 healing" if r.cls=="Healer" and (int(r.level)+1)%4==0 else "")+(" · trait unlock" if r.level==4 else ""),12,GOLD)
  var detail = disclosure(box,"Specialization & bonds","recruit_"+str(index))
  label(detail,{"Warrior":"+5% hero defense","Archer":"+3% hero critical chance","Healer":"+5 hero HP"}[r.cls]+" while alive.\nLevel 5: "+Model.recruit_trait(r),12,MUTED)
  label(detail,"LOYALTY %d / 30\n%s" % [r.loyalty,Model.bond_story(r)],12,GOLD)
  label(detail,"One loyalty after a safe return at wave 5+. At 30: +2 personal HP once.",11,MUTED)
  if r.dead:
   button(box,"Revive · "+Model.cost_text(model.revive_cost(r)),"revive:"+str(index),model.locked() or not model.can_pay(model.revive_cost(r)))
  else:
   label(box,"READY TO MARCH",10,GOLD)
 var hiring = disclosure(content,"Recruit companions · "+("barracks ready" if model.s.buildings.has("barracks") else "barracks required"),"hiring")
 var choices_grid = GridContainer.new()
 choices_grid.columns = 3
 hiring.add_child(choices_grid)
 for cls in ["Warrior","Archer","Healer"]:
  var box = card(choices_grid,cls)
  portrait(box,cls,Vector2(64,80))
  label(box,{"Warrior":"+5% hero defense","Archer":"+3% hero crit","Healer":"+5 hero HP and small heals"}[cls],12,MUTED)
  label(box,Model.cost_text(model.recruit_cost()),11,MUTED)
  button(box,"Hire "+cls,"recruit:"+cls,model.locked() or model.s.recruits.size()>=3 or not model.s.buildings.has("barracks") or not model.can_pay(model.recruit_cost()))
 support_ui(disclosure(content,"Barracks requirements","recruit_support"))

func treasury_ui() -> void:
 var grid = GridContainer.new()
 grid.columns = 2
 content.add_child(grid)
 var recovery = card(grid,"Hero recovery")
 label(recovery,"Your hero fell." if model.s.heroDead else "Your hero is ready to descend.",15,GOLD)
 var cost = model.revive_cost()
 button(recovery,"Revive · "+Model.cost_text(cost),"hero",not model.s.heroDead or model.locked() or not model.can_pay(cost))
 label(recovery,"Revived %d times · future gold +35%% and food +25%% each time" % model.s.heroRevives,12,MUTED)
 button(recovery,"Emergency revival loan","loan",not model.s.heroDead or model.locked() or model.s.debt+model.s.interest>0)
 if model.s.heroDead and model.s.debt+model.s.interest>0:
  live_labels.recover = button(recovery,"Free recovery · 5 minutes","recover",model.s.recover>0)
 var debt = card(grid,"Outstanding debt")
 label(debt,"Principal %.2f gold\nInterest %.2f gold\nExpeditions until interest %d" % [model.s.debt,model.s.interest,5-model.s.loanRuns],16,GOLD)
 button(debt,"Repay up to 10 gold","repay",model.s.debt+model.s.interest<=0 or model.s.gold<=0)
 var terms = disclosure(debt,"Loan terms","loan_terms")
 label(terms,"1% of remaining principal every five expeditions. No offline interest. Pay interest first. A second loan is blocked until debt is cleared. Loans revive only the hero.",12,MUTED)

func progression_ui() -> void:
 history_ui(content)
 var prestige = card(content,"Prestige %d" % model.s.meta.prestiges)
 label(prestige,"+%d%% hero attack, HP, and worker income · %d prestige Grave Essence" % [model.s.meta.prestiges*5,model.s.meta.essence],16,GOLD)
 var description = disclosure(prestige,"What resets & what survives","prestige_info")
 label(description,"Defeat a boss and repay debt, then reset your adventure for %d essence and another permanent 5%% bonus. Gear, settlement, troops, specialists, resources, and routes reset. Talents, permanent bonuses, journal preferences, and lifetime history survive. Prestige essence is separate from crafting essence." % model.prestige_reward(),12,MUTED)
 button(prestige,"Begin a new lifetime…","prestige",model.locked() or model.s.cycleBosses<1 or model.s.debt+model.s.interest>0)
 var grid = GridContainer.new()
 grid.columns = 3
 content.add_child(grid)
 for key in ["warrior","survivor","treasure"]:
  var level = int(model.s.talents[key])
  var box = card(grid,{"warrior":"Warrior","survivor":"Survivor","treasure":"Treasure Hunter"}[key])
  label(box,"Rank %d / 5" % level,12,GOLD)
  label(box,{"warrior":"+5% hero attack","survivor":"+5% hero HP","treasure":"+5% loot value and rare-drop chances"}[key]+" per rank.",12,MUTED)
  progress(box,level,5)
  button(box,"Learn · %d prestige essence" % (level+1),"talent:"+key,model.locked() or level>=5 or model.s.meta.essence<level+1)

func open_dialog(title: String, width: int = 600) -> VBoxContainer:
 if modal!=null and is_instance_valid(modal):
  modal.hide()
  modal.queue_free()
 modal = AcceptDialog.new()
 modal.title = title
 modal.min_size = Vector2i(width,200)
 modal.dialog_autowrap = true
 modal.dialog_hide_on_ok = true
 modal.get_ok_button().text = "Close"
 add_child(modal)
 var box = VBoxContainer.new()
 box.custom_minimum_size.x = width-60
 if title=="Settlement interaction":
  var viewport = ScrollContainer.new()
  viewport.custom_minimum_size = Vector2(740,440)
  viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  modal.add_child(viewport)
  box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  viewport.add_child(box)
 else:
  modal.add_child(box)
 return box

func popup_dialog() -> void:
 modal.popup_centered()

func show_journal(topic: String) -> void:
 var box = open_dialog("Survivor’s journal · "+topic,620)
 label(box,topic,23,GOLD)
 label(box,Model.JOURNAL[topic],14,MUTED)
 var tabs = HFlowContainer.new()
 box.add_child(tabs)
 for key in Model.JOURNAL:
  var b = Button.new()
  b.text = key
  tabs.add_child(b)
  b.pressed.connect(func(): show_journal(key))
 var opt_out = CheckButton.new()
 opt_out.text = "Don't show tutorials again"
 opt_out.button_pressed = model.s.tutorialsDisabled
 opt_out.toggled.connect(func(value): model.s.tutorialsDisabled=value; save_progress())
 box.add_child(opt_out)
 if not model.s.seen.has(topic): model.s.seen.append(topic)
 save_progress()
 popup_dialog()

func inventory_dialog() -> void:
 var box = open_dialog("Inventory",760)
 label(box,"Crafting materials",22,GOLD)
 for key in Model.MATERIALS+["blueprints"]:
  label(box,"%s · %d" % [key.capitalize(),model.s.blueprints if key=="blueprints" else model.s.items[key]],14,TEXT)
 label(box,"Iron upgrades equipment. Rivets forge tiers. Leather forges gloves, boots, and capes. Crafting essence forges neck and ring pieces. Blueprints are consumed on forging.",12,MUTED)
 var bag_scroll = ScrollContainer.new()
 bag_scroll.custom_minimum_size = Vector2(650,280)
 bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 box.add_child(bag_scroll)
 var bag = VBoxContainer.new()
 bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 bag_scroll.add_child(bag)
 for index in range(model.s.equipmentBag.size()): item_row(bag,index,false)
 if model.s.equipmentBag.is_empty(): label(bag,"No spare equipment yet.",13,MUTED)
 popup_dialog()

func confirm_salvage(index: int) -> void:
 if index<0 or index>=model.s.equipmentBag.size() or model.locked(): return
 var target = model.s.equipmentBag[index]
 var box = open_dialog("Confirm salvage")
 label(box,"Salvage "+model.gear_item(target.slot,int(target.tier),int(target.get("upgrade",0))).name+"?",22,GOLD)
 label(box,"This permanently removes this spare. Equipped gear is safe.\nReturns "+Model.cost_text(Model.SALVAGE.get(target.rarity,Model.SALVAGE.common)),14,MUTED)
 var confirm = Button.new()
 confirm.text = "Salvage item"
 confirm.name = "salvage_confirm"
 box.add_child(confirm)
 confirm.pressed.connect(func():
  # Object identity protects against an index changing while the confirmation is open.
  var current = model.s.equipmentBag.find(target)
  if current>=0 and model.salvage_item(current):
   modal.hide()
   save_progress()
   render_tab())
 popup_dialog()

func settings_dialog() -> void:
 var box = open_dialog("Save settings")
 label(box,"Native desktop adventure",22,GOLD)
 label(box,"Local saves are automatic with a previous-good backup. Import browser JSON to continue an existing adventure. Import/reset replaces the current profile, including its server save when signed in.",13,MUTED)
 var actions = row(box)
 button(actions,"Import JSON…","import",accounts.busy)
 button(actions,"Export JSON…","export")
 button(box,"Toggle fullscreen · F11","fullscreen")
 button(box,"Reset this profile…","reset",accounts.busy)
 popup_dialog()

func choose_save_file(importing: bool) -> void:
 if importing and (model.locked() or accounts.busy):
  show_toast("Finish the expedition or queue before replacing your save.")
  return
 if file_dialog!=null and is_instance_valid(file_dialog): file_dialog.queue_free()
 file_dialog = FileDialog.new()
 file_dialog.title = "Import Gravehold save" if importing else "Export Gravehold save"
 file_dialog.access = FileDialog.ACCESS_FILESYSTEM
 file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
 file_dialog.filters = PackedStringArray(["*.json ; Gravehold JSON save"])
 file_dialog.current_file = "gravehold-save.json" if not importing else ""
 file_dialog.file_selected.connect(func(path):
  if importing:
   var source = JSON.parse_string(FileAccess.get_file_as_string(path))
   var check = Model.new()
   if not check.load_state(source): show_toast(check.last_error); return
   confirm_import(source)
  elif not store.export_file(path,model.serialize()): show_toast(store.last_error)
  else: show_toast("Save exported."))
 add_child(file_dialog)
 file_dialog.popup_centered(Vector2i(800,560))

func confirm_import(source: Dictionary) -> void:
 var box = open_dialog("Replace current save?")
 label(box,"Import this adventure?",22,GOLD)
 label(box,"The current profile will be backed up and replaced. Account sync will upload the imported state if signed in.",14,MUTED)
 var b = Button.new()
 b.text = "Import and replace"
 box.add_child(b)
 b.pressed.connect(func():
  if model.load_state(source):
   restore_world_position()
   model.accrue()
   selected_slot = ""
   tab = "Expeditions" if not model.battle.is_empty() else "Settlement"
   modal.hide()
   save_progress()
   render_tab())
 popup_dialog()

func confirm_reset() -> void:
 var box = open_dialog("Reset current profile")
 label(box,"Type RESET to erase this profile",22,GOLD)
 label(box,"This clears settlement, hero, gear, troops, specialists, talents, debt, prestige, and history. Your account remains.",14,MUTED)
 var input = LineEdit.new()
 input.placeholder_text = "RESET"
 box.add_child(input)
 var confirm = Button.new()
 confirm.text = "Reset progress"
 confirm.name = "reset_confirm"
 confirm.disabled = true
 box.add_child(confirm)
 input.text_changed.connect(func(value): confirm.disabled=value!="RESET")
 confirm.pressed.connect(func():
  model.reset()
  selected_slot = ""
  panels.clear()
  tab = "Settlement"
  modal.hide()
  save_progress()
  render_tab())
 popup_dialog()

func confirm_prestige() -> void:
 var box = open_dialog("Begin a new lifetime?")
 label(box,"Prestige for %d Grave Essence" % model.prestige_reward(),22,GOLD)
 label(box,"Your adventure resets. Permanent bonuses, talents, and lifetime history survive.",14,MUTED)
 var b = Button.new()
 b.text = "Prestige now"
 box.add_child(b)
 b.pressed.connect(func():
  if model.prestige():
   selected_slot = ""
   panels.clear()
   tab = "Settlement"
   modal.hide()
   save_progress()
   render_tab())
 popup_dialog()

func account_dialog() -> void:
 var box = open_dialog("Account & cross-device saves",650)
 if not accounts.email.is_empty():
  label(box,"Signed in · "+accounts.email,20,GOLD)
  label(box,"Server saves sync every five seconds. Local account backups stay on this computer. Sessions are not stored; sign in again after restarting.",13,MUTED)
  var logout_button = Button.new()
  logout_button.text = "Sign out"
  logout_button.disabled = accounts.busy
  box.add_child(logout_button)
  logout_button.pressed.connect(func(): if accounts.logout(): modal.hide())
 else:
  label(box,"Connect to your Gravehold server",22,GOLD)
  label(box,"Guest play is fully offline. Email accounts use the existing Node server. Use HTTPS on a deployed host; localhost HTTP is for development. Google accounts need a native OAuth handoff and are not supported by this desktop adapter yet.",13,MUTED)
  var endpoint = LineEdit.new()
  endpoint.text = accounts.server_url
  endpoint.placeholder_text = "https://your-save-server.example"
  box.add_child(endpoint)
  var email_input = LineEdit.new()
  email_input.placeholder_text = "Email"
  box.add_child(email_input)
  var password = LineEdit.new()
  password.secret = true
  password.placeholder_text = "Password · at least 8 characters"
  box.add_child(password)
  var actions = row(box)
  for registering in [false,true]:
   var b = Button.new()
   b.text = "Create account" if registering else "Sign in"
   actions.add_child(b)
   b.pressed.connect(func():
    if accounts.busy: return
    save_progress()
    guest_snapshot = model.serialize()
    account_message.text = "Connecting…"
    accounts.authenticate(email_input.text,password.text,registering,endpoint.text)
    password.text = "")
 account_message = label(box,"",12,GOLD)
 popup_dialog()

func _account_status(message: String) -> void:
 if account_message!=null and is_instance_valid(account_message): account_message.text = message
 show_toast(message)
 update_resources()

func _account_loaded(data: Variant) -> void:
 if accounts.email.is_empty():
  store.path = "user://save.json"
  var guest = store.read()
  model.load_state(guest if guest!=null else guest_snapshot)
 else:
  store.path = "user://account_"+accounts.email.sha256_text().substr(0,16)+".json"
  if data!=null:
   if not model.load_state(data):
    show_toast("Server save is invalid. Local state was not overwritten.")
    accounts.email = ""
    accounts.cookie = ""
    store.path = "user://save.json"
    return
  model.accrue()
 restore_world_position()
 tab = "Expeditions" if not model.battle.is_empty() else "Settlement"
 selected_slot = ""
 if modal!=null: modal.hide()
 save_progress()
 render_tab()

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F11:
  dispatch("fullscreen")

func prepare_demo() -> void:
 model.reset()
 model.s.tutorialsDisabled = true
 model.s.buildings = {"wood":1,"stone":1,"food":1,"barracks":1,"woodStorage":3,"stoneStorage":3,"foodStorage":3}
 model.s.workers = {"wood":{"xp":650},"stone":{"xp":320},"food":{"xp":400}}
 model.s.wood = 380
 model.s.stone = 240
 model.s.food = 300
 model.s.gold = 820
 model.s.gear.weapon = 2
 model.s.gear.body = 1
 model.s.gear.head = 1
 model.s.gearRarities.weapon = "rare"
 model.s.recruits = [{"cls":"Warrior","name":"Aldric","level":3,"xp":9,"loyalty":14,"dead":false,"revives":0},{"cls":"Archer","name":"Mira","level":2,"xp":4,"loyalty":11,"dead":false,"revives":0}]
 model.s.equipmentBag = [{"slot":"head","tier":2,"upgrade":0,"rarity":"rare","newFind":true},{"slot":"weapon","tier":1,"upgrade":2,"rarity":"common","newFind":true}]
