extends SceneTree
const World = preload("res://scripts/settlement_world.gd")
const Model = preload("res://scripts/game_model.gd")
var failures: Array[String] = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
 checks += 1
 if not value: failures.append(title)
func settle() -> void:
 for i in range(4): await process_frame
func run() -> void:
 var world = World.new()
 world.model = Model.new()
 root.add_child(world)
 await settle()
 world.set_process(false)
 world.can_move = func(): return true
 var held = InputEventKey.new()
 held.keycode = KEY_D
 held.physical_keycode = KEY_D
 held.pressed = true
 var initial = world.hero_position
 Input.parse_input_event(held)
 Input.flush_buffered_events()
 world._process(.1)
 held = held.duplicate()
 held.pressed = false
 Input.parse_input_event(held)
 Input.flush_buffered_events()
 check(world.hero_position.x>initial.x,"physical D key moves the hero")
 var start = world.hero_position
 world.move_hero(Vector2.RIGHT,.1)
 check(world.hero_position.x>start.x,"hero moves through world")
 world.hero_position = Vector2(185,207)
 world.move_hero(Vector2.UP,.2)
 check(world.hero_position.y==207,"building collision stops walking inside")
 world.hero_position = Vector2(535,535)
 world.move_hero(Vector2.DOWN,10)
 check(world.hero_position.y<=610,"world bounds contain hero")
 var arrived: Array[String] = []
 world.interacted.connect(func(key): arrived.append(key))
 for key in World.STATIONS:
  world.hero_position = Vector2(535,535)
  world.walk_to(World.STATIONS[key].point)
  for i in range(2000):
   world._process(.016)
   if not world.walking_to: break
  check(not world.walking_to and not arrived.is_empty() and arrived[-1]==key,"click navigation reaches "+key)
 world.hero_position = Vector2(650,550)
 check(world.nearest_station().is_empty(),"distant sites cannot be used with E")
 world.queue_free()
 await process_frame
 var app = load("res://scenes/main.tscn").instantiate()
 root.add_child(app)
 await settle()
 if app.modal!=null: app.modal.hide()
 app.model.reset()
 app.model.s.tutorialsDisabled = true
 app.render_tab()
 await settle()
 check(not app.nav_buttons.Recruits.visible,"settlement hides secondary menu tabs")
 app.world.hero_position = Vector2(185,235)
 var key = InputEventKey.new()
 key.physical_keycode = KEY_E
 key.pressed = true
 Input.parse_input_event(key)
 await settle()
 check(app.modal.visible and app.station_key=="wood","E opens nearby gathering site")
 app.dispatch("gather:wood")
 check(app.model.s.gather!=null,"world gathering starts existing timer")
 check(app.world.hero_position==Vector2(185,235),"actions preserve hero location")
 app.model.s.gather.end = 0
 app._second()
 app.dispatch("gather:wood")
 check(app.model.s.wood==12 and app.model.s.gather==null,"timed world gathering collects resources")
 app.model.s.wood = 40
 app.model.s.stone = 10
 app.model.s.food = 15
 app.dispatch("build:wood")
 check(app.model.s.buildings.has("wood"),"world construction updates actual settlement")
 app.dispatch("worker:wood")
 check(app.model.s.workers.has("wood"),"world worker hire updates production")
 app.modal.hide()
 app.open_station("barracks")
 check(app.find_child("barracks",true,false).disabled,"barracks keeps original progression requirements")
 for station in ["camp","treasury","forge"]:
  app.open_station(station)
  await settle()
  check(app.modal.visible,"native interaction at "+station)
 app.modal.hide()
 app.world.hero_position = Vector2(640,550)
 app.dispatch("tab:Loadout")
 app.dispatch("tab:Settlement")
 await settle()
 check(app.world.hero_position==Vector2(640,550),"returning from equipment preserves location")
 app.save_progress()
 var loaded = Model.new()
 check(loaded.load_state(app.store.read()) and Vector2(loaded.s.settlementPosition[0],loaded.s.settlementPosition[1])==Vector2(640,550),"hero position survives saving and reopening")
 app.open_station("gate")
 check(app.tab=="Expeditions","gate connects to actual dungeon selection")
 print("Settlement world checks: %d passed, %d failed" % [checks-failures.size(),failures.size()])
 for failure in failures: printerr("FAIL: "+failure)
 app.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
