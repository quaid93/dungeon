extends SceneTree
const Model = preload("res://scripts/game_model.gd")
const Store = preload("res://scripts/save_store.gd")
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
 test_browser_parity()
 test_economy()
 test_equipment()
 test_battle()
 test_revival()
 test_objectives_bonds_specialists()
 test_queue_prestige()
 test_save_round_trip()
 print("Native gameplay checks: %d passed, %d failed" % [checks-failures.size(),failures.size()])
 for failure in failures:
  printerr("FAIL: "+failure)
 quit(0 if failures.is_empty() else 1)

func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures.append(message)

func equal(actual: Variant, expected: Variant, message: String) -> void:
 if (actual is float or actual is int) and (expected is float or expected is int):
  check(is_equal_approx(float(actual),float(expected)),message+" (%s vs %s)" % [actual,expected])
 else:
  check(deep_equal(actual,expected),message+" (%s vs %s)" % [actual,expected])

func deep_equal(a: Variant, b: Variant) -> bool:
 if (a is float or a is int) and (b is float or b is int): return is_equal_approx(float(a),float(b))
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size(): return false
  for k in a:
   if not b.has(k) or not deep_equal(a[k],b[k]): return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size(): return false
  for i in range(a.size()):
   if not deep_equal(a[i],b[i]): return false
  return true
 return a==b

func test_browser_parity() -> void:
 var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/browser_parity.json"))
 for f in fixtures:
  var m = Model.new()
  check(m.load_state(f.state),"browser save imports: "+f.name)
  for key in f.hero: equal(m.hero_stats()[key],f.hero[key],f.name+" hero "+key)
  equal(m.upgrade_cost("weapon"),f.upgrade,f.name+" upgrade costs")
  equal(m.forge_cost("weapon"),f.forge,f.name+" forging costs")
  equal(m.gather_yield("wood"),f.gather,f.name+" manual gathering")
  equal(m.income_rate("wood"),f.income,f.name+" worker income")
  equal(m.revive_cost(),f.revive,f.name+" scaled revival")
  for i in range(f.recruits.size()):
   var actual = m.recruit_unit(m.s.recruits[i],i)
   for key in ["maxHp","attack","defense","crit"]: equal(actual[key],f.recruits[i][key],"recruit parity "+key)

func test_economy() -> void:
 var m = Model.new()
 m.reset(0)
 check(m.start_gather("wood",0),"manual gathering starts")
 check(not m.collect_gather(7999),"gather not early")
 check(m.collect_gather(8000),"gather finishes")
 equal(m.s.wood,12,"starter gathering yield")
 check(not m.collect_gather(9000),"gather cannot duplicate")
 m.s.workers.wood = {"xp":0}
 m.accrue(60000,false)
 equal(m.s.wood,42,"offline income half rate")
 m.s.last = 0
 m.s.wood = 0
 m.accrue(60000,true)
 equal(m.s.wood,60,"online income full rate")
 m.accrue(3600000,false)
 equal(m.s.wood,100,"storage caps resources")
 m.s.wood = 100
 m.s.stone = 100
 check(m.upgrade_storage("wood"),"storage upgrade purchases")
 equal(m.cap("wood"),250,"storage grows")
 equal(m.storage_cost("wood").wood,75,"storage prices scale")
 m.s.gatherCounts.wood = 25
 check(m.gather_yield("wood")>20,"manual gathering scales")
 m.s.foreman = true
 m.start_gather("food",0)
 m.accrue(9000,true)
 equal(m.s.gather,null,"foreman collects ready task")
 equal(m.s.food,12,"foreman receives task yield")
 check(not m.build_barracks(),"barracks milestones gate")
 m.s.workers.stone = {"xp":0}
 m.s.workers.food = {"xp":0}
 m.s.history.best = 5
 m.s.wood = 5000
 m.s.stone = 5000
 m.s.food = 5000
 m.s.gold = 5000
 check(m.build_barracks(),"established settlement constructs barracks")
 check(m.hire_recruit("Warrior"),"recruit hired with farm and dungeon resources")
 check(m.recruit_cost().gold>150,"hiring scales")

func test_equipment() -> void:
 var m = Model.new()
 equal(m.s.gear.weapon,-1,"no starter gear")
 equal(Model.SLOTS.size(),10,"ten slots")
 m.s.gear.weapon = 2
 m.s.gearRarities.weapon = "rare"
 m.s.equipmentBag = [{"slot":"weapon","tier":1,"upgrade":0,"rarity":"legendary","newFind":true},{"slot":"weapon","tier":3,"upgrade":0,"rarity":"common","newFind":true}]
 var before = m.serialize()
 equal(m.ranked_items("weapon")[0].index,1,"combat gains beat rarity sorting")
 equal(m.serialize(),before,"comparisons don't mutate save")
 equal(m.item_comparison(m.s.equipmentBag[0]).attack,-6,"comparison exposes loss")
 check(m.equip_item(1),"direct equip")
 equal(m.s.equipmentBag[-1].newFind,false,"swapped item handled")
 check(m.dismiss_item(0),"dismiss works")
 equal(m.s.equipmentBag.size(),2,"dismiss keeps inventory")
 equal(m.s.equipmentBag[0].newFind,false,"dismiss persists")
 check(m.salvage_item(0),"salvage works")
 equal(m.s.gold,600,"rarity-scaled salvage")
 equal(m.s.gear.weapon,3,"salvage leaves equipped item safe")
 m.s.gold = 10000
 m.s.items.iron = 100
 m.s.items.rivets = 100
 m.s.blueprints = 2
 check(m.upgrade_item("weapon"),"upgrade purchases")
 equal(m.s.gearUpgrades.weapon,1,"upgrade applied")
 check(m.forge_item("weapon"),"forge consumes blueprint")
 equal(m.s.blueprints,1,"blueprint consumed")
 equal(m.s.gearUpgrades.weapon,0,"forging resets upgrade")
 check(not m.forge_item("head"),"blueprints do not create starter gear")
 m.s.gear.body = 2
 m.s.gear.head = 2
 m.s.gear.legs = 2
 check(m.hero_stats().health>75,"set bonus applied")

func test_battle() -> void:
 var m = Model.new()
 m.rng.seed = 16
 m.s.recruits = [{"cls":"Warrior","name":"Aldric","level":1,"xp":0,"loyalty":0,"dead":false,"revives":0}]
 m.start_battle({"d":0,"name":"Test","mod":1})
 var hp = m.battle.enemies[0].hp
 m.tick_battle()
 check(m.battle.enemies[0].hp<hp,"actual hero attack damages enemy")
 equal(m.battle.allies[1].hp,m.battle.allies[1].maxHp,"warrior stays behind hero")
 var original = m.serialize()
 var rng_state = m.rng.state
 m.forecast({"d":0,"mod":1,"modifier":"none","name":"Forecast"})
 equal(m.serialize(),original,"forecast leaves live state alone")
 equal(m.rng.state,rng_state,"forecast leaves actual random sequence alone")
 m.s.gear.weapon = 100
 m.s.gear.body = 100
 m.start_battle({"d":0,"name":"Winning","mod":1})
 for i in range(100):
  if m.battle.checkpoint: break
  m.tick_battle()
 equal(m.battle.wave,5,"first checkpoint wave 5")
 equal(m.battle.phase,"checkpoint","battle idles at checkpoint")
 check(m.battle.allies.all(func(u): return not u.has("event")),"no attacking after wave")
 var beat = m.battle.beat
 m.tick_battle()
 equal(m.battle.beat,beat,"checkpoint cannot auto-advance")
 check(m.extract(),"checkpoint extraction")
 equal(m.s.history.runs,1,"history recorded")
 check(m.s.lastExpedition.report.damage.hero>0,"real combat report records damage")
 m.start_battle({"d":0,"name":"Loss","mod":1})
 m.battle.allies[0].hp = 1
 m.battle.allies[0].attack = 0
 m.s.gear.weapon = -1
 m.s.gear.body = -1
 m.battle.enemies[0].hp = 10000
 m.battle.enemies[0].attack = 100
 m.tick_battle()
 check(m.s.heroDead,"hero defeat recorded")
 equal(m.s.gear.weapon,-1,"defeat doesn't grant loot")
 check(m.s.lastExpedition.report.lastHit!=null,"defeat records attacker")

func test_revival() -> void:
 var m = Model.new()
 m.s.heroDead = true
 check(not m.revive_hero(),"paid revive blocked without funds")
 equal(m.s.heroRevives,0,"failed revival doesn't scale")
 check(m.revive_hero(true),"hero-only emergency loan")
 equal(m.s.debt,55,"loan covers missing gold and food")
 equal(m.s.heroRevives,1,"loan revival scales")
 m.s.heroDead = true
 check(not m.revive_hero(true),"second loan blocked")
 check(m.begin_recovery(0),"free recovery while indebted")
 m.accrue(300000,false)
 check(not m.s.heroDead,"five minute recovery completes")
 equal(m.s.heroRevives,2,"recovery scales revival cost")
 m.s.debt = 100
 m.s.interest = 10
 m.s.loanRuns = 0
 for i in range(5): m.record_run(false,1,{"gold":0},{"d":0,"name":"Loss"})
 equal(m.s.interest,11,"simple interest every five expeditions")
 m.s.gold = 10
 check(m.repay(),"manual repayment")
 equal(m.s.interest,1,"interest repaid first")
 equal(m.s.debt,100,"principal unchanged until interest covered")

func test_objectives_bonds_specialists() -> void:
 var m = Model.new()
 m.s.recruits = [{"cls":"Healer","name":"Elara","level":1,"xp":0,"loyalty":29,"dead":false,"revives":0}]
 m.start_battle({"d":0,"name":"Solo","mod":1,"objective":"solo"})
 equal(m.battle.allies.size(),1,"solo leaves companion home")
 equal(m.battle.allies[0].maxHp,75,"solo removes companion passive")
 m.battle.wave = 10
 check(not m.objective_complete(),"reached wave is not cleared wave")
 m.battle.clearedWave = 10
 check(m.objective_complete(),"solo objective completes")
 m.finish(true)
 equal(m.s.gold,25,"fixed objective reward")
 equal(m.s.objectivesCompleted,1,"objective claimed once")
 equal(m.s.recruits[0].xp,0,"benched companion gets no XP")
 equal(m.s.recruits[0].loyalty,29,"benched companion gets no loyalty")
 m.start_battle({"d":0,"name":"Safe","mod":1,"objective":"safe"})
 m.battle.wave = 10
 m.battle.clearedWave = 10
 m.finish(true)
 equal(m.s.recruits[0].loyalty,30,"bond cap reached on safe return")
 equal(m.recruit_unit(m.s.recruits[0],0).maxHp,23,"bond grants two personal HP")
 m.start_battle({"d":0,"name":"Rescue","mod":1})
 m.battle.wave = 15
 m.rescue_specialist()
 equal(m.battle.rescue,"blacksmith","boss frees first missing resident")
 m.finish(false)
 check(m.s.specialists.is_empty(),"failed extraction forfeits rescue")
 m.s.heroDead = false
 m.start_battle({"d":0,"name":"Rescue","mod":1})
 m.battle.wave = 15
 m.rescue_specialist()
 m.finish(true)
 check(m.s.specialists.blacksmith,"safe rescue settles resident")
 m.s.wood = 1000
 m.s.stone = 1000
 m.s.gold = 1000
 m.s.gear.weapon = 1
 var price = m.upgrade_cost("weapon")
 check(m.specialist_service("blacksmith"),"workshop paid service")
 equal(m.upgrade_cost("weapon").gold,ceil(price.gold*.9),"workshop discounts only ten percent gold")
 equal(m.upgrade_cost("weapon").iron,price.iron,"no material discount")
 check(not m.specialist_service("blacksmith"),"workshop cannot stack")
 m.s.specialists.quartermaster = true
 m.s.food = 0
 check(m.specialist_service("quartermaster"),"quartermaster sells food")
 check(not m.specialist_service("quartermaster"),"one food purchase per expedition")

func test_queue_prestige() -> void:
 var m = Model.new()
 check(not m.start_queue("0",1,0),"uncleared route rejects queue")
 m.s.gear.weapon = 100
 m.s.gear.body = 100
 m.s.clearedDungeons["0"] = {"d":0,"name":"Cleared","mod":1,"modifier":"none","focus":"balanced"}
 m.s.objective = "solo"
 check(m.start_queue("0",1,0),"cleared route queues")
 check(not m.equip_item(0),"gear changes blocked while away")
 m.resolve_queue(300000)
 equal(m.s.offlineQueue,null,"queue settles")
 equal(m.s.history.runs,1,"queued run records history")
 equal(m.s.objectivesCompleted,0,"no objectives in queue")
 check(m.s.specialists.is_empty(),"no rescues in queue")
 var gold = m.s.gold
 m.resolve_queue(900000)
 equal(m.s.gold,gold,"queue cannot award twice")
 check(m.prestige(),"boss enables prestige")
 equal(m.s.meta.prestiges,1,"permanent prestige count")
 equal(m.s.meta.essence,5,"boss-scaled prestige reward")
 equal(m.s.gear.weapon,-1,"prestige clears adventure gear")
 equal(m.s.history.runs,1,"lifetime history retained")
 check(not m.prestige(),"prestige cannot repeat without new boss")
 check(m.buy_talent("warrior"),"talent purchases")
 equal(m.s.talents.warrior,1,"talent retained")

func test_save_round_trip() -> void:
 var m = Model.new()
 m.s.wood = 77
 m.start_battle({"d":0,"name":"Resume","mod":1})
 m.tick_battle()
 var store = Store.new()
 store.path = "user://native-test.json"
 check(store.write(m.serialize()),"atomic save writes")
 var restored = Model.new()
 check(restored.load_state(store.read()),"save reopens")
 equal(restored.s.wood,77,"resources round trip")
 equal(restored.battle.beat,m.battle.beat,"live battle resumes")
 equal(restored.battle.allies[0].hp,m.battle.allies[0].hp,"live HP preserved")
 var original = restored.serialize()
 check(not restored.load_state({"oops":true}),"invalid import rejected")
 equal(restored.serialize(),original,"invalid import doesn't overwrite progress")
 check(store.write(m.serialize()),"backup created on subsequent save")
 var file = FileAccess.open(store.path,FileAccess.WRITE)
 file.store_string("bad JSON")
 file.close()
 check(store.read() is Dictionary,"corrupt primary recovers backup")
 for path in [store.path,store.path+".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
