extends SceneTree
var app: Control
var failures: Array[String] = []
var checks = 0

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, title: String) -> void:
 checks += 1
 if not value: failures.append(title)

func settle() -> void:
 for i in range(4): await process_frame

func run() -> void:
 var scene = load("res://scenes/main.tscn")
 app = scene.instantiate()
 root.add_child(app)
 await settle()
 if app.modal!=null: app.modal.hide()
 app.model.s.tutorialsDisabled = true
 app.prepare_demo()
 app.render_tab()
 await settle()
 check(app.find_child("gather_wood",true,false)!=null,"native settlement action exists")
 app.model.reset()
 app.model.s.tutorialsDisabled = true
 app.model.s.workers.wood = {"xp":0}
 app.model.s.wood = 19.5
 app.model.s.stone = 10
 app.render_tab()
 await settle()
 check(app.find_child("build_wood",true,false).disabled,"unaffordable building is disabled")
 app.model.s.last = app.model.now_ms()-1000
 app._second()
 await settle()
 check(not app.find_child("build_wood",true,false).disabled,"income enables newly affordable action without tab switching")
 app.prepare_demo()
 app.dispatch("tab:Loadout")
 await settle()
 check(app.find_child("upgrade_weapon",true,false)==null,"no upgrade details until selected")
 app.dispatch("slot:head")
 await settle()
 check(app.find_child("equip_0",true,false)!=null,"slot equipment available directly")
 check(app.model.s.equipmentBag.size()==2,"inspection keeps new finds")
 app.dispatch("equip:0")
 await settle()
 check(app.model.s.gear.head==2,"native equip control applies item")
 check(app.find_child("upgrade_head",true,false)!=null,"selected item upgrade controls appear")
 for title in ["Recruits","Treasury","Progression"]:
  app.dispatch("tab:"+title)
  await settle()
  check(app.tab==title,"native "+title+" navigation")
 app.dispatch("tab:Expeditions")
 await settle()
 check(app.find_child("enter_0",true,false)!=null,"native dungeon choices")
 app.model.s.gear.weapon = 100
 app.model.s.gear.body = 100
 app.dispatch("enter:0")
 await settle()
 check(app.world!=null,"native battle scene exists")
 for i in range(100):
  if app.model.battle.checkpoint: break
  app.model.tick_battle()
 app.render_tab()
 await settle()
 check(app.find_child("extract",true,false)!=null,"checkpoint extraction control")
 app.find_child("extract",true,false).pressed.emit()
 await settle()
 check(app.model.battle.is_empty(),"native extraction finishes battle")
 check(app.model.s.lastExpedition.report.damage.hero>0,"native debrief contains actual battle")
 app.inventory_dialog()
 await settle()
 check(app.modal.visible,"native inventory dialog")
 app.modal.hide()
 app.model.s.gear.weapon = 2
 app.model.s.gear.body = 1
 app.dispatch("tab:Loadout")
 await settle()
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/tmp/gravehold-godot-loadout.png")
 app.dispatch("tab:Settlement")
 await settle()
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/tmp/gravehold-godot-settlement.png")
 app.model.start_battle({"d":0,"name":"Hollow Crypt","mod":1,"modifier":"none","focus":"equipment"})
 app.tab = "Expeditions"
 app.render_tab()
 await settle()
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/tmp/gravehold-godot-battle.png")
 print("Native UI checks: %d passed, %d failed" % [checks-failures.size(),failures.size()])
 for failure in failures: printerr("FAIL: "+failure)
 app.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
