class_name GraveholdModel
extends RefCounted
## Native rules engine. Camel-case save keys intentionally match the browser format.
## No UI, disk access, or network side effects; tests can inject time and RNG seeds.

signal equipment_discovered(item: Dictionary, wave: int)
signal expedition_finished

const RESOURCES = ["wood", "stone", "food"]
const MATERIALS = ["iron", "rivets", "leather", "essence"]
const SLOTS = ["head", "cape", "neck", "weapon", "body", "shield", "legs", "hands", "feet", "ring"]
const SLOT_STATS = {"head":"defense", "cape":"health", "neck":"attack", "weapon":"attack", "body":"defense", "shield":"defense", "legs":"defense", "hands":"attack", "feet":"health", "ring":"attack"}
const NOUNS = {"head":"helm", "cape":"cloak", "neck":"pendant", "weapon":"blade", "body":"cuirass", "shield":"shield", "legs":"greaves", "hands":"gloves", "feet":"boots", "ring":"signet"}
const RARITIES = ["common", "uncommon", "rare", "epic", "legendary"]
const SALVAGE = {"common":{"gold":20,"iron":1}, "uncommon":{"gold":50,"iron":2,"rivets":1}, "rare":{"gold":120,"iron":4,"rivets":2,"essence":1}, "epic":{"gold":250,"iron":8,"rivets":4,"essence":2}, "legendary":{"gold":600,"iron":15,"rivets":8,"essence":5}}
const BARRACKS_COST = {"wood":700, "stone":600, "food":400, "gold":120}
const WORKSHOP_COST = {"wood":300, "stone":250, "gold":150}
const MODIFIERS = {"none":"Unmodified", "double":"Double Loot", "elite":"Elite Enemies", "wounded":"Starting Damage"}
const RESOURCE_HELP = {
 "wood":"Build sites, expand storage, and hire workers and troops. Staffed woodcutting: +1 hero attack.",
 "stone":"Build sites, expand storage, and hire troops. Staffed quarry: +1 hero defense.",
 "food":"Hire workers and troops and pay for revivals. Staffed homestead: +5 hero HP. Dungeon entry is free.",
 "gold":"Earned in dungeons and salvage. Funds equipment, recruitment, revival, specialists, and debt. No passive income."
}
const OBJECTIVES = {
 "none":{"name":"No objective", "help":"Standard rewards.", "reward":{}},
 "solo":{"name":"Lone descent", "help":"Travel alone. Clear wave 10, then extract. Companions stay home.", "reward":{"gold":25}},
 "elite":{"name":"Elite hunter", "help":"Clear wave 5 on an Elite Enemies route, then extract.", "reward":{"iron":1}},
 "safe":{"name":"Bring everyone home", "help":"Clear wave 10 with at least one recruit and every companion alive, then extract.", "reward":{"food":30,"rivets":1}}
}
const SPECIALISTS = {
 "blacksmith":{"name":"Varric", "role":"Blacksmith", "help":"Build a workshop for 10% lower item-upgrade gold costs. Materials and forging costs stay the same."},
 "quartermaster":{"name":"Nessa", "role":"Quartermaster", "help":"Buy 25 food for 20 gold, once per completed expedition. Requires storage space."},
 "scout":{"name":"Corvin", "role":"Scout", "help":"Pay 20 gold to survey three new routes. No better enemies or drop odds."}
}
const JOURNAL = {
 "Settlement":"Move with WASD or arrows; press E near a building, or click it to walk there. Trees, quarry and homestead offer gathering and construction. Barracks manages recruits; blacksmith opens equipment; campfire offers prestige and talents; quartermaster manages revivals and debt; the gate opens expeditions. Gather for 8 seconds, then collect. Practice, workers, and storage increase yields. Build a site to unlock dungeons, then hire its worker. Workers produce at half rate while away, until storage fills. Staff all three professions and reach wave five to establish a barracks. Rescued specialists move into your settlement and offer paid services.",
 "Expeditions":"Combat is automatic. Forecasts simulate your actual team and estimate a full clear, not a guaranteed outcome. Extract at waves 5 and 10 or face the boss at 15. Unsecured rewards are lost on defeat. Choose a reward focus and an optional fixed-reward objective. Equipment chance is capped at 18%; Double Loot does not duplicate gear. Wave 10 may free a specialist; a boss frees one missing resident. Extract to bring them home.",
 "Loadout":"Ten hero slots, no arrow slot. Start with no equipment. Rare finds roll at waves 5, 10, and 15. Extract to keep gear, then equip directly from New finds or a selected slot. Comparisons include set bonuses. Upgrade with scaling gold and iron costs. Consumed blueprints forge the next tier of existing gear. Dismiss hides a find but keeps it; confirmed salvage converts spare equipment into rarity-scaled resources.",
 "Recruits":"The hero leads; smaller companions act every other turn. Warrior: +5% hero defense; Archer: +3% hero crit; Healer: +5 hero HP and small heals. Level up every 20 participated expeditions survived: +2 personal HP each level, +1 attack every fourth level, and a modest level-five trait. Loyalty grows after successful returns at wave 5 or later. Memories at 10/20 culminate at 30 with one +2 personal HP bonus. Benched troops earn no progression.",
 "Treasury":"Gold and food revive fallen characters. Each successful revival increases that character's future price. Emergency borrowing revives only your hero, with one outstanding loan maximum. Every five completed expeditions adds 1% interest on remaining principal; no offline interest. Repay manually. While in debt, free hero recovery takes five minutes.",
 "Progression":"Defeat a boss and repay all debt to prestige. Reset your adventure for permanent +5% hero attack, HP, and worker income and prestige Grave Essence. This is separate from crafting essence. Talents and lifetime history survive. Fully cleared routes unlock up to three offline runs at five minutes each and half rewards. No objectives or specialist rescues in queued runs."
}

var s: Dictionary = {}
var battle: Dictionary = {}
var rng = RandomNumberGenerator.new()
var simulating = false
var risk_cache: Dictionary = {}
var last_error = ""

func _init() -> void:
 rng.randomize()
 reset()

static func now_ms() -> float:
 return Time.get_unix_time_from_system() * 1000.0

func reset(at: float = -1) -> void:
 if at < 0:
  at = now_ms()
 s = {"wood":0.0,"stone":0.0,"food":0.0,"gold":0.0,"buildings":{},"workers":{},"recruits":[],"gear":{},"gearUpgrades":{},"gearRarities":{},"items":{},"equipmentBag":[],"blueprints":0,"seen":[],"last":at,"gather":null,"heroDead":false,"recover":0,"debt":0.0,"interest":0.0,"expeditions":0,"loanRuns":0,"log":["Your story begins at the edge of the woods."],"choices":null,"specialists":{},"objective":"none","rewardFocus":"balanced","quartermasterRun":-1,"objectivesCompleted":0,"meta":{"prestiges":0,"essence":0},"talents":{"warrior":0,"survivor":0,"treasure":0},"history":{"runs":0,"best":0,"bosses":0,"gold":0,"recent":[]},"cycleBosses":0,"clearedDungeons":{},"offlineQueue":null,"foreman":false,"tutorialsDisabled":false,"lootAlert":null,"heroRevives":0,"gatherCounts":{},"lastExpedition":null,"settlementPosition":[535,535]}
 for key in SLOTS:
  s.gear[key] = -1
  s.gearUpgrades[key] = 0
  s.gearRarities[key] = "common"
 for key in MATERIALS:
  s.items[key] = 0
 battle = {}
 risk_cache.clear()

func load_state(raw: Variant) -> bool:
 if not raw is Dictionary:
  last_error = "Save must contain a JSON object."
  return false
 var candidate = raw.get("state", raw)
 if not candidate is Dictionary:
  last_error = "Save payload must be an object."
  return false
 var incoming: Dictionary = candidate
 # Reject clearly unrelated or structurally invalid files before changing a live save.
 if not incoming.has("gear") or not incoming.get("buildings") is Dictionary or not incoming.get("recruits") is Array:
  last_error = "This file is not a Gravehold save."
  return false
 var previous = s.duplicate(true)
 var previous_battle = battle.duplicate(true)
 reset()
 for key in s.keys():
  if incoming.has(key):
   var value = incoming[key]
   if s[key] is Dictionary and not value is Dictionary:
    s = previous
    battle = previous_battle
    last_error = "Invalid dictionary field: " + key
    return false
   if s[key] is Array and not value is Array:
    s = previous
    battle = previous_battle
    last_error = "Invalid list field: " + key
    return false
   s[key] = value
 if s.gear.has("armor"):
  s.gear.body = s.gear.armor
  s.gearUpgrades.body = s.gearUpgrades.get("armor", 0)
  s.gear.erase("armor")
  s.gearUpgrades.erase("armor")
 for key in SLOTS:
  s.gear[key] = int(s.gear.get(key, -1))
  s.gearUpgrades[key] = int(s.gearUpgrades.get(key, 0))
  s.gearRarities[key] = s.gearRarities.get(key, default_rarity(s.gear[key]))
 for key in MATERIALS:
  s.items[key] = int(s.items.get(key, 0))
 for key in ["wood", "stone", "food", "gold", "last", "debt", "interest", "recover"]:
  if not (s[key] is int or s[key] is float):
   s = previous
   battle = previous_battle
   last_error = "Invalid number: " + key
   return false
  s[key] = maxf(0, float(s[key]))
 for i in range(s.recruits.size()):
  var r = s.recruits[i]
  if not r is Dictionary or not ["Warrior", "Archer", "Healer"].has(r.get("cls")):
   s = previous
   battle = previous_battle
   last_error = "Invalid recruit."
   return false
  r["revives"] = int(r.get("revives", 0))
  r["name"] = r.get("name", recruit_name(r.cls, i))
  r["loyalty"] = clampi(int(r.get("loyalty", 0)), 0, 30)
  r["level"] = maxi(1, int(r.get("level", 1)))
  r["xp"] = int(r.get("xp", 0))
  r["dead"] = r.get("dead", false)
 for item in s.equipmentBag:
  if not item is Dictionary or not SLOTS.has(item.get("slot")):
   s = previous
   battle = previous_battle
   last_error = "Invalid equipment."
   return false
  item["rarity"] = item.get("rarity", default_rarity(int(item.get("tier", 1))))
  item["newFind"] = item.get("newFind", true)
  item["upgrade"] = int(item.get("upgrade", 0))
 s.history.merge({"runs":s.expeditions,"best":0,"bosses":0,"gold":0,"recent":[]}, false)
 s.meta.merge({"prestiges":0,"essence":0}, false)
 s.talents.merge({"warrior":0,"survivor":0,"treasure":0}, false)
 if not OBJECTIVES.has(s.objective):
  s.objective = "none"
 if not ["balanced", "gold", "materials", "equipment"].has(incoming.get("rewardFocus", "balanced")):
  s.rewardFocus = "balanced"
 else:
  s.rewardFocus = incoming.get("rewardFocus", "balanced")
 if incoming.get("activeBattle") is Dictionary:
  battle = incoming.activeBattle.duplicate(true)
  if not battle.get("allies") is Array or not battle.get("enemies") is Array:
   # Very old percentage-HP browser saves resume through the native combat model.
   var old = battle.duplicate(true)
   start_battle(old, true)
   battle.wave = int(old.get("wave", 1))
   battle.loot.merge(old.get("loot", {}), true)
   battle.checkpoint = old.get("checkpoint", false)
   battle.allies[0].hp = maxf(1, battle.allies[0].maxHp * float(old.get("hp", 100)) / 100)
   spawn_wave()
  battle["stats"] = battle.get("stats", {"damage":{},"healing":{},"taken":0,"lastHit":null})
  battle["clearedWave"] = battle.get("clearedWave", maxi(0, int(battle.wave) - 1))
  battle["objective"] = battle.get("objective", "none")
  battle["objectiveAwarded"] = battle.get("objectiveAwarded", false)
  battle.loot["equipment"] = battle.loot.get("equipment", [])
  battle["balance"] = 4
 last_error = ""
 risk_cache.clear()
 return true

func serialize() -> Dictionary:
 var result = s.duplicate(true)
 result["saveVersion"] = 2
 result["client"] = "godot"
 result["activeBattle"] = null if battle.is_empty() else battle.duplicate(true)
 return result

static func default_rarity(tier: int) -> String:
 return ["common","common","uncommon","rare","epic","legendary"][clampi(tier, 0, 5)]

static func cost_text(cost: Dictionary) -> String:
 var parts: PackedStringArray = []
 for key in cost:
  parts.append("%s %s" % [cost[key], key])
 return " · ".join(parts)

static func stat_text(stats: Dictionary, delta: bool = false) -> String:
 var parts: PackedStringArray = []
 for key in stats:
  var v = float(stats[key])
  var sign_text = ("+" if v > 0 else "−") if delta else ""
  var value = absf(v) if delta else v
  var amount = "%d%%" % roundi(value * 100) if key in ["crit","evade","leech"] else str(snappedf(value, .01))
  var title = "HP" if key == "health" else "life steal" if key == "leech" else key
  parts.append(sign_text + amount + " " + title)
 return " · ".join(parts) if not parts.is_empty() else "Same combat stats"

func add_log(message: String) -> void:
 s.log.push_front(message)
 if s.log.size() > 30:
  s.log.resize(30)

func cap(key: String) -> int:
 return 100 + int(s.buildings.get(key + "Storage", 0)) * 150

func income_rate(key: String) -> float:
 if not s.workers.has(key):
  return 0
 return (1 + floorf(s.workers[key].xp / 300.0) * .2) * (1 + s.meta.prestiges * .05)

func can_pay(cost: Dictionary, materials: bool = false) -> bool:
 for key in cost:
  var value = s.items.get(key, 0) if materials and MATERIALS.has(key) else s.get(key, 0)
  if value < cost[key]:
   return false
 return true

func pay(cost: Dictionary, materials: bool = false) -> bool:
 if not can_pay(cost, materials):
  last_error = "Not enough resources."
  return false
 for key in cost:
  if materials and MATERIALS.has(key):
   s.items[key] -= cost[key]
  else:
   s[key] -= cost[key]
 return true

func storage_cost(key: String) -> Dictionary:
 var level = int(s.buildings.get(key + "Storage", 0))
 return {"wood":35+level*40,"stone":25+level*30}

func gather_yield(key: String) -> int:
 var worker_level = 1 + floori(s.workers[key].xp / 300.0) if s.workers.has(key) else 0
 return floori(12 + sqrt(float(s.gatherCounts.get(key, 0))) * 2 + s.buildings.get(key+"Storage", 0)*4 + worker_level*4)

func start_gather(key: String, at: float = -1) -> bool:
 if not RESOURCES.has(key) or s.gather != null:
  return false
 if at < 0:
  at = now_ms()
 s.gather = {"kind":key,"end":at+8000,"amount":gather_yield(key)}
 return true

func collect_gather(at: float = -1) -> bool:
 if at < 0:
  at = now_ms()
 if s.gather == null or at < s.gather.end:
  return false
 var key = s.gather.kind
 var amount = minf(s.gather.get("amount", gather_yield(key)), maxf(0, cap(key)-s[key]))
 s[key] += amount
 s.gatherCounts[key] = s.gatherCounts.get(key, 0) + 1
 add_log("Gathered %d %s." % [amount, key])
 s.gather = null
 return true

func accrue(at: float = -1, online: bool = false) -> void:
 if at < 0:
  at = now_ms()
 var seconds = maxf(0, (at - s.last) / 1000.0)
 for key in s.workers:
  s[key] = minf(cap(key), s[key] + seconds * (1.0 if online else .5) * income_rate(key))
  s.workers[key].xp += seconds
 s.last = at
 if s.heroDead and s.recover > 0 and at >= s.recover:
  s.heroDead = false
  s.recover = 0
  s.heroRevives += 1
  add_log("Your hero has recovered.")
 if s.foreman and s.gather != null and at >= s.gather.end:
  collect_gather(at)
 resolve_queue(at)

func build_site(key: String) -> bool:
 if not RESOURCES.has(key) or s.buildings.has(key) or not pay({"wood":20,"stone":10}):
  return false
 s.buildings[key] = 1
 add_log("Production site built. Dungeon gates are open.")
 return true

func hire_worker(key: String) -> bool:
 if not s.buildings.has(key) or s.workers.has(key) or not pay({"wood":20,"food":15}):
  return false
 s.workers[key] = {"xp":0.0}
 return true

func train_worker(key: String) -> bool:
 if not s.workers.has(key):
  return false
 if not pay({key:30+floori(s.workers[key].xp/300.0)*15}):
  return false
 s.workers[key].xp += 300
 return true

func upgrade_storage(key: String) -> bool:
 if not RESOURCES.has(key) or not pay(storage_cost(key)):
  return false
 s.buildings[key+"Storage"] = s.buildings.get(key+"Storage", 0)+1
 return true

func barracks_ready() -> bool:
 return s.workers.has("wood") and s.workers.has("stone") and s.workers.has("food") and s.history.best >= 5

func build_barracks() -> bool:
 if s.buildings.has("barracks") or not barracks_ready() or not pay(BARRACKS_COST):
  return false
 s.buildings.barracks = 1
 return true

func hire_foreman() -> bool:
 if s.foreman or s.workers.size() < 3 or not pay({"wood":300,"stone":200,"food":250}):
  return false
 s.foreman = true
 return true

func locked() -> bool:
 return not battle.is_empty() or s.offlineQueue != null

static func recruit_name(cls: String, index: int) -> String:
 return {"Warrior":["Aldric","Bran","Oswin"],"Archer":["Mira","Rowan","Ash"],"Healer":["Elara","Sable","Iona"]}.get(cls, ["Traveler"])[index % 3 if cls in ["Warrior","Archer","Healer"] else 0]

func recruit_cost() -> Dictionary:
 var n = s.recruits.size()
 return {"wood":900+n*450,"stone":750+n*350,"food":800+n*400,"gold":150+n*100}

func hire_recruit(cls: String) -> bool:
 if locked() or not s.buildings.has("barracks") or s.recruits.size() >= 3 or not ["Warrior","Archer","Healer"].has(cls) or not pay(recruit_cost()):
  return false
 s.recruits.append({"cls":cls,"name":recruit_name(cls,s.recruits.size()),"level":1,"xp":0,"loyalty":0,"dead":false,"revives":0})
 return true

func recruit_unit(r: Dictionary, index: int) -> Dictionary:
 var level = int(r.get("level", 1))
 var cls = r.cls
 var hp = (23 if cls == "Warrior" else 17 if cls == "Archer" else 19) + level*2 + (2 if r.get("loyalty",0) >= 30 else 0)
 return {"id":"recruit-"+str(index),"name":r.get("name",recruit_name(cls,index)),"kind":cls,"role":cls,"index":index,"maxHp":hp,"hp":0 if r.get("dead",false) else hp,"attack":(3 if cls=="Archer" else 2 if cls=="Warrior" else 1)+floori(level/4.0),"defense":(2 if cls=="Warrior" else 0)+(1 if cls=="Warrior" and level>=5 else 0),"crit":(.06 if cls=="Archer" else .02)+(.02 if cls=="Archer" and level>=5 else 0),"evade":0,"leech":0}

static func recruit_trait(r: Dictionary) -> String:
 return "Steadfast · +1 personal defense" if r.cls=="Warrior" else "Keen eye · +2% personal crit" if r.cls=="Archer" else "Mercy · +1 healing per cast"

static func bond_story(r: Dictionary) -> String:
 var loyalty = r.get("loyalty",0)
 if loyalty < 10:
  return "Trust grows with every safe return."
 var memories = {"Warrior":["reveals how their old watchtower fell.","entrusts you with the badge of their lost regiment.","swears to guard the home you have built."],"Archer":["speaks of a forest they can never return to.","shows a map drawn by their missing sibling.","plants a sapling in Gravehold and calls it home."],"Healer":["recalls keeping a candle lit through the plague.","shares the names of those they could not save.","plants healing herbs and chooses to stay."]}
 return r.get("name",r.cls)+" "+memories[r.cls][2 if loyalty>=30 else 1 if loyalty>=20 else 0]+(" Bond complete: +2 personal HP." if loyalty>=30 else "")

func gear_item(key: String, tier: int = -99, upgrade: int = -1) -> Dictionary:
 if not SLOTS.has(key):
  return {}
 if tier == -99:
  tier = int(s.gear[key])
 if tier < 0:
  return {}
 if upgrade < 0:
  upgrade = int(s.gearUpgrades[key])
 var prefix = ["Worn","Iron","Gravewarden","Duskforged"][tier] if tier<=3 else "Ancient "+str(tier)
 var kind = SLOT_STATS[key]
 var value = 2+tier*7+upgrade*2 if kind=="health" else (3+tier*6 if key=="weapon" else 1+tier*2)+upgrade*2 if kind=="attack" else 1+tier*2+upgrade
 var stats = {kind:value}
 if tier>0 and key=="ring":
  stats.crit = tier*.02
 if tier>0 and key=="cape":
  stats.evade = tier*.015
 if tier>0 and key=="neck":
  stats.leech = tier*.015
 return {"name":prefix+" "+NOUNS[key],"tier":tier,"upgrade":upgrade,"stats":stats}

func hero_stats(include_recruits: bool = true) -> Dictionary:
 var total = {"attack":9.0,"defense":0.0,"health":75.0,"crit":.05,"evade":0.0,"leech":0.0}
 for key in SLOTS:
  var item = gear_item(key)
  if not item.is_empty():
   for stat in item.stats:
    total[stat] += item.stats[stat]
 total.attack += 1 if s.workers.has("wood") else 0
 total.defense += 1 if s.workers.has("stone") else 0
 total.health += 5 if s.workers.has("food") else 0
 var warriors = 0
 if include_recruits:
  for r in s.recruits:
   if not r.dead:
    if r.cls=="Warrior":
     warriors += 1
    elif r.cls=="Archer":
     total.crit += .03
    else:
     total.health += 5
 total.defense = snappedf(total.defense*(1+warriors*.05), .01)
 total.attack = roundi(total.attack*(1+s.meta.prestiges*.05+s.talents.warrior*.05))
 var set_count = 0
 for key in SLOTS:
  if s.gear[key]==2:
   set_count += 1
 total.health = roundi(total.health*(1+s.meta.prestiges*.05+s.talents.survivor*.05)*(1.1 if set_count>=3 else 1))
 total.crit = minf(.5,total.crit)
 total.evade = minf(.35,total.evade)
 total.leech = minf(.25,total.leech)
 return total

func item_comparison(item: Dictionary) -> Dictionary:
 var before = hero_stats()
 var key = item.slot
 var old = [s.gear[key],s.gearUpgrades[key],s.gearRarities[key]]
 s.gear[key] = item.tier
 s.gearUpgrades[key] = item.get("upgrade",0)
 s.gearRarities[key] = item.get("rarity",default_rarity(item.tier))
 var after = hero_stats()
 s.gear[key] = old[0]
 s.gearUpgrades[key] = old[1]
 s.gearRarities[key] = old[2]
 var delta = {}
 for stat in before:
  var value = snappedf(after[stat]-before[stat], .001)
  if value != 0:
   delta[stat] = value
 return delta

static func item_score(delta: Dictionary) -> float:
 return delta.get("attack",0)*2+delta.get("defense",0)*2+delta.get("health",0)/5.0+delta.get("crit",0)*80+delta.get("evade",0)*100+delta.get("leech",0)*80

func ranked_items(key: String) -> Array:
 var result = []
 for index in range(s.equipmentBag.size()):
  var item = s.equipmentBag[index]
  if item.slot==key:
   result.append({"item":item,"index":index,"delta":item_comparison(item)})
 result.sort_custom(func(a,b):
  var score_a = item_score(a.delta)
  var score_b = item_score(b.delta)
  if score_a != score_b:
   return score_a > score_b
  if a.item.rarity != b.item.rarity:
   return RARITIES.find(a.item.rarity) > RARITIES.find(b.item.rarity)
  return a.item.tier>b.item.tier)
 return result

func equip_item(index: int) -> bool:
 if locked() or index<0 or index>=s.equipmentBag.size():
  return false
 var item = s.equipmentBag[index]
 var old = gear_item(item.slot)
 s.equipmentBag.remove_at(index)
 if not old.is_empty():
  s.equipmentBag.append({"slot":item.slot,"tier":old.tier,"upgrade":old.upgrade,"rarity":s.gearRarities[item.slot],"newFind":false})
 s.gear[item.slot] = int(item.tier)
 s.gearUpgrades[item.slot] = int(item.get("upgrade",0))
 s.gearRarities[item.slot] = item.rarity
 risk_cache.clear()
 add_log("Equipped "+gear_item(item.slot).name+".")
 return true

func dismiss_item(index: int) -> bool:
 if index<0 or index>=s.equipmentBag.size():
  return false
 s.equipmentBag[index].newFind = false
 return true

func salvage_item(index: int) -> bool:
 if locked() or index<0 or index>=s.equipmentBag.size():
  return false
 var item = s.equipmentBag[index]
 var reward = SALVAGE.get(item.rarity,SALVAGE.common)
 s.equipmentBag.remove_at(index)
 for key in reward:
  if key=="gold":
   s.gold += reward[key]
  else:
   s.items[key] += reward[key]
 add_log("Salvaged equipment for "+cost_text(reward)+".")
 return true

func upgrade_cost(key: String) -> Dictionary:
 var level = int(s.gearUpgrades[key])
 var tier = maxi(0,int(s.gear[key]))
 return {"gold":ceili((150+tier*50+level*100+level*level*25)*(.9 if s.buildings.has("workshop") else 1)),"iron":8+tier*2+level*4}

func forge_cost(key: String) -> Dictionary:
 var tier = maxi(0,int(s.gear[key]))
 var cost = {"iron":18+tier*8,"rivets":12+tier*6,"gold":600+tier*400}
 if key in ["cape","hands","feet"]:
  cost.leather = 10+tier*5
 if key in ["ring","neck"]:
  cost.essence = 6+tier*3
 return cost

func upgrade_item(key: String) -> bool:
 if locked() or not SLOTS.has(key) or s.gear[key]<0 or not pay(upgrade_cost(key),true):
  return false
 s.gearUpgrades[key] += 1
 risk_cache.clear()
 return true

func forge_item(key: String) -> bool:
 if locked() or not SLOTS.has(key) or s.gear[key]<0 or s.blueprints<1 or not pay(forge_cost(key),true):
  return false
 s.blueprints -= 1
 s.gear[key] = maxi(1,s.gear[key]+1)
 s.gearUpgrades[key] = 0
 risk_cache.clear()
 return true

func revive_cost(recruit: Dictionary = {}) -> Dictionary:
 var n = int(recruit.get("revives",0)) if not recruit.is_empty() else int(s.heroRevives)
 return {"gold":ceili((15 if not recruit.is_empty() else 25)*pow(1.35,n)),"food":ceili((10 if not recruit.is_empty() else 15)*pow(1.25,n))}

func revive_hero(borrow: bool = false) -> bool:
 if locked() or not s.heroDead:
  return false
 var cost = revive_cost()
 if borrow:
  if s.debt+s.interest>0:
   return false
  s.debt = maxf(0,cost.gold-s.gold)+maxf(0,cost.food-s.food)*2
  s.gold = maxf(0,s.gold-cost.gold)
  s.food = maxf(0,s.food-cost.food)
  s.loanRuns = 0
 elif not pay(cost):
  return false
 s.heroDead = false
 s.recover = 0
 s.heroRevives += 1
 return true

func revive_recruit(index: int) -> bool:
 if locked() or index<0 or index>=s.recruits.size():
  return false
 var r = s.recruits[index]
 if not r.dead or not pay(revive_cost(r)):
  return false
 r.dead = false
 r.revives += 1
 return true

func begin_recovery(at: float = -1) -> bool:
 if locked() or not s.heroDead or s.debt+s.interest<=0 or s.recover>0:
  return false
 s.recover = (now_ms() if at<0 else at)+300000
 return true

func repay() -> bool:
 var amount = minf(10,minf(s.gold,s.debt+s.interest))
 if amount<=0:
  return false
 var paid_interest = minf(amount,s.interest)
 s.gold -= amount
 s.interest -= paid_interest
 s.debt = maxf(0,s.debt-(amount-paid_interest))
 return true

func choices() -> Array:
 if s.choices==null:
  var names = [["Hollow Crypt","Ashen Chapel","Forgotten Tomb"],["Bleak Catacombs","Widow’s Keep","Sunken Abbey"],["Blood Cathedral","Throne of Cinders","The Black Ossuary"]]
  s.choices = []
  for d in range(3):
   s.choices.append({"d":d,"name":names[d][rng.randi_range(0,2)],"mod":rng.randf_range(.9,1.1),"modifier":["none","double","elite","wounded"][rng.randi_range(0,3)]})
 return s.choices

func gates_open() -> bool:
 for key in RESOURCES:
  if s.buildings.has(key):
   return true
 return false

func enter_dungeon(index: int) -> bool:
 if locked() or s.heroDead or not gates_open() or index<0 or index>2:
  return false
 var c = choices()[index].duplicate(true)
 c.focus = s.get("rewardFocus","balanced")
 c.objective = s.objective
 start_battle(c)
 return true

func start_battle(c: Dictionary, importing: bool = false) -> void:
 var h = hero_stats(c.get("objective","none")!="solo")
 battle = c.duplicate(true)
 battle.merge({"balance":4,"wave":1,"beat":0,"checkpoint":false,"phase":"combat","clearedWave":0,"objectiveAwarded":false,"events":["The expedition enters the dungeon."],"loot":empty_loot(),"allies":[{"id":"hero","name":"Your hero","kind":"hero","role":"Hero","hp":h.health,"maxHp":h.health,"attack":h.attack,"defense":h.defense,"crit":h.crit,"evade":h.evade,"leech":h.leech}],"enemies":[],"stats":{"damage":{},"healing":{},"taken":0,"lastHit":null}},true)
 if c.get("objective","none")!="solo":
  for i in range(s.recruits.size()):
   battle.allies.append(recruit_unit(s.recruits[i],i))
 if c.get("modifier","none")=="wounded":
  battle.allies[0].hp = roundi(h.health*.75)
 spawn_wave()
 if not importing:
  add_log("Entered "+str(c.get("name","Dungeon"))+".")

static func empty_loot() -> Dictionary:
 return {"gold":0,"wood":0,"stone":0,"food":0,"iron":0,"rivets":0,"leather":0,"essence":0,"blueprints":0,"equipment":[]}

func battle_event(message: String) -> void:
 battle.events.push_front(message)
 if battle.events.size()>12:
  battle.events.resize(12)

func spawn_wave() -> void:
 var d = int(battle.d)
 var wave = int(battle.wave)
 var modifier = float(battle.get("mod",1))*(1.25 if battle.get("modifier","none")=="elite" else 1)
 var boss = wave==15
 var count = 1 if boss else mini(4,1+floori((wave-1)/5.0)+d)
 battle.enemies = []
 for index in range(count):
  var hp = roundi((70+d*55 if boss else 13+wave*2+d*13)*modifier)
  battle.enemies.append({"id":"enemy-"+str(index),"name":"Ossuary lord" if boss else "Crypt archer" if index%2 else "Bone guard","kind":"boss" if boss else "enemyArcher" if index%2 else "enemy","role":"Boss" if boss else "Archer" if index%2 else "Warrior","hp":hp,"maxHp":hp,"attack":roundi((12+d*6 if boss else 4+wave*.35+d*3)*modifier),"defense":3+d*2 if boss else floori(wave/6.0)+d,"crit":.15 if boss else .04,"evade":0,"leech":0})
 battle.phase = "combat"
 battle_event("Wave %d: %s." % [wave,"the dungeon lord awakens" if boss else "%d enemies approach" % count])

func heal_unit(source: Dictionary, target: Dictionary, amount: float) -> void:
 var actual = minf(amount,target.maxHp-target.hp)
 if actual<=0:
  return
 target.hp += actual
 battle.stats.healing[source.id] = battle.stats.healing.get(source.id,0)+actual
 target.event = {"beat":battle.beat,"kind":"heal","text":"+"+str(int(actual))}
 source.event = {"beat":battle.beat,"kind":"attack","text":"Heal"}
 battle_event("%s restores %d HP to %s." % [source.name,actual,target.name])

func hit(source: Dictionary, target: Dictionary) -> void:
 source.event = {"beat":battle.beat,"kind":"attack","text":"Strike"}
 if rng.randf()<target.get("evade",0):
  target.event = {"beat":battle.beat,"kind":"damage","text":"Dodge"}
  battle_event(target.name+" dodges "+source.name+".")
  return
 var critical = rng.randf()<source.get("crit",0)
 var damage = maxi(1,roundi((source.attack*rng.randf_range(.9,1.1)-target.defense*.55)*(1.7 if critical else 1)))
 var actual = minf(target.hp,damage)
 target.hp = maxf(0,target.hp-damage)
 target.event = {"beat":battle.beat,"kind":"damage","text":("Crit " if critical else "−")+str(int(actual))}
 if source.id=="hero" or source.has("index"):
  battle.stats.damage[source.id] = battle.stats.damage.get(source.id,0)+actual
 if target.id=="hero":
  battle.stats.taken += actual
  battle.stats.lastHit = {"name":source.name,"role":source.role,"damage":actual}
 battle_event("%s hits %s for %d%s." % [source.name,target.name,actual," (critical)" if critical else ""])
 if source.get("leech",0)>0 and source.hp>0:
  var healing = minf(source.maxHp-source.hp,ceili(actual*source.leech))
  source.hp += healing
  battle.stats.healing[source.id] = battle.stats.healing.get(source.id,0)+healing
 if target.hp<=0:
  battle_event(target.name+" falls.")
  if target.has("index"):
   s.recruits[int(target.index)].dead = true

func clear_effects() -> void:
 for unit in battle.allies+battle.enemies:
  unit.erase("event")

func objective_complete() -> bool:
 var key = battle.get("objective","none")
 var wave = int(battle.get("clearedWave",0))
 if key=="solo":
  return wave>=10 and battle.allies.size()==1
 if key=="elite":
  return wave>=5 and battle.get("modifier","none")=="elite"
 if key=="safe":
  return wave>=10 and battle.allies.size()>1 and battle.allies.all(func(u): return u.hp>0)
 return false

func rescue_specialist() -> void:
 if battle.get("queued",false) or battle.has("rescue"):
  return
 var missing = []
 for key in SPECIALISTS:
  if not s.specialists.get(key,false):
   missing.append(key)
 if missing.is_empty():
  return
 if battle.wave==15 or (battle.wave==10 and rng.randf()<.08):
  battle.rescue = missing[0]
  battle_event(SPECIALISTS[missing[0]].name+" is freed. Extract safely to bring them home.")

func reward_wave() -> void:
 clear_effects()
 battle.clearedWave = battle.wave
 rescue_specialist()
 var double = battle.get("modifier","none")=="double"
 var multiplier = (battle.d+1)*(2 if double else 1)
 var hunter = 1+s.talents.treasure*.05
 var quantity = 2 if double else 1
 var focus = battle.get("focus","balanced")
 battle.loot.gold += floori(multiplier*(4+rng.randi_range(0,5))*hunter*(1.6 if focus=="gold" else 1))
 for key in RESOURCES:
  battle.loot[key] += floori(multiplier*2*hunter)
 var probs = {"iron":.08,"rivets":.06,"leather":.05,"essence":.025}
 for key in probs:
  if rng.randf()<(probs[key]+battle.d*.01)*hunter*(2 if focus=="materials" else 1):
   battle.loot[key] += quantity
 if rng.randf()<(.015+battle.d*.005)*hunter*(1.5 if focus=="materials" else 1):
  battle.loot.blueprints += quantity
 var equipment_probability = minf(.18,(.08+battle.d*.02)*hunter*(1.75 if focus=="equipment" else 1))
 if int(battle.wave)%5==0 and rng.randf()<equipment_probability:
  var roll = rng.randf()
  var key = "weapon" if roll<.3 else "body" if roll<.45 else SLOTS[rng.randi_range(0,9)]
  var rarity_roll = rng.randf()
  var rarity = "common"
  if battle.d==0:
   rarity = "common" if rarity_roll<.8 else "uncommon" if rarity_roll<.98 else "rare"
  elif battle.d==1:
   rarity = "common" if rarity_roll<.45 else "uncommon" if rarity_roll<.85 else "rare" if rarity_roll<.99 else "epic"
  else:
   rarity = "uncommon" if rarity_roll<.5 else "rare" if rarity_roll<.9 else "epic" if rarity_roll<.99 else "legendary"
  var item = {"slot":key,"tier":1+int(battle.d),"upgrade":0,"rarity":rarity,"newFind":true}
  battle.loot.equipment.append(item)
  if not simulating:
   s.lootAlert = {"name":gear_item(key,item.tier,0).name,"rarity":rarity,"stats":stat_text(gear_item(key,item.tier,0).stats),"wave":battle.wave,"until":now_ms()+10000}
   equipment_discovered.emit(item,battle.wave)
 battle_event("Wave cleared. Rewards added to unsecured spoils.")
 if battle.wave==15:
  finish(true)
 elif int(battle.wave)%5==0:
  battle.checkpoint = true
  battle.phase = "checkpoint"
 else:
  battle.phase = "between"
  battle.nextAt = battle.beat+2

func continue_battle() -> bool:
 if battle.is_empty() or not battle.checkpoint:
  return false
 clear_effects()
 battle.checkpoint = false
 battle.wave += 1
 for unit in battle.allies:
  if unit.hp>0:
   unit.hp = minf(unit.maxHp,unit.hp+roundi(unit.maxHp*.2))
 spawn_wave()
 return true

func tick_battle() -> void:
 if battle.is_empty() or battle.checkpoint or battle.has("result"):
  return
 var stats = hero_stats(battle.get("objective","none")!="solo")
 var hero = battle.allies[0]
 hero.attack = stats.attack
 hero.defense = stats.defense
 hero.crit = stats.crit
 hero.maxHp = stats.health
 hero.hp = minf(hero.hp,hero.maxHp)
 battle.beat += 1
 if battle.phase=="between":
  if battle.beat>=battle.nextAt:
   battle.wave += 1
   spawn_wave()
  return
 for unit in battle.allies:
  if unit.hp<=0 or (unit.role!="Hero" and int(battle.beat)%2!=0):
   continue
  if unit.role=="Healer":
   var injured = battle.allies.filter(func(u): return u.hp>0 and u.hp<u.maxHp)
   injured.sort_custom(func(a,b): return a.hp/float(a.maxHp)<b.hp/float(b.maxHp))
   if not injured.is_empty():
    var level = s.recruits[int(unit.index)].level
    heal_unit(unit,injured[0],3+floori(level/4.0)+(1 if level>=5 else 0))
    continue
  var targets = battle.enemies.filter(func(u): return u.hp>0)
  if not targets.is_empty():
   hit(unit,targets[0])
 if battle.enemies.all(func(u): return u.hp<=0):
  reward_wave()
  return
 for unit in battle.enemies:
  if unit.hp<=0:
   continue
  var allies = battle.allies.filter(func(u): return u.hp>0)
  if not allies.is_empty():
   hit(unit,allies[-1] if unit.role=="Archer" else allies[0])
  if hero.hp<=0:
   finish(false)
   return

func report(won: bool) -> Dictionary:
 var result = battle.stats.duplicate(true)
 result.won = won
 result.names = {"hero":"Hero"}
 for unit in battle.allies:
  result.names[unit.id] = unit.name
 var recommendation = "Invest secured rewards in your next equipment upgrade."
 if not won:
  if result.lastHit!=null and result.lastHit.role=="Boss":
   recommendation = "More defense and HP would help against the boss."
  elif battle.allies.slice(1).any(func(u): return u.hp<=0):
   recommendation = "Revive fallen companions and improve hero defense before returning."
  else:
   recommendation = "Try an easier route or improve hero HP and defense."
 result.recommendation = recommendation
 return result

func secure_loot(loot: Dictionary) -> void:
 for item in loot.get("equipment",[]):
  s.equipmentBag.append(item.duplicate(true))
 s.gold += loot.get("gold",0)
 for key in RESOURCES:
  s[key] = minf(cap(key),s[key]+loot.get(key,0))
 for key in MATERIALS:
  s.items[key] += loot.get(key,0)
 s.blueprints += loot.get("blueprints",0)

func record_run(won: bool, wave: int, loot: Dictionary, dungeon: Dictionary) -> void:
 s.expeditions += 1
 s.history.runs += 1
 s.history.best = maxi(s.history.best,wave)
 if won and wave==15:
  s.history.bosses += 1
  s.cycleBosses += 1
  s.clearedDungeons[str(dungeon.d)] = {"d":dungeon.d,"name":dungeon.name,"mod":dungeon.get("mod",1),"modifier":dungeon.get("modifier","none"),"focus":dungeon.get("focus","balanced")}
 s.history.gold += loot.get("gold",0) if won else 0
 s.history.recent.push_front({"name":dungeon.get("name","Dungeon"),"wave":wave,"won":won,"gold":loot.get("gold",0) if won else 0})
 if s.history.recent.size()>8:
  s.history.recent.resize(8)
 if s.debt>0:
  s.loanRuns += 1
  if s.loanRuns>=5:
   s.interest += s.debt*.01
   s.loanRuns = 0
 for index in range(s.recruits.size()):
  var r = s.recruits[index]
  if r.dead or (dungeon.has("allies") and not dungeon.allies.any(func(u): return u.get("index",-1)==index)):
   continue
  if won and wave>=5:
   r.loyalty = mini(30,int(r.loyalty)+1)
   if r.loyalty in [10,20,30]:
    add_log(bond_story(r))
  r.xp += 1
  if r.xp>=20:
   r.level += 1
   r.xp = 0
   add_log(r.name+" reached level "+str(r.level)+": +2 HP"+(" · +1 attack" if int(r.level)%4==0 else "")+(" · class trait unlocked" if r.level==5 else ""))

func finish(won: bool) -> void:
 if simulating:
  battle.result = "win" if won else "loss"
  return
 var objective_name = null
 if won and not battle.get("objectiveAwarded",false) and objective_complete():
  var objective = OBJECTIVES[battle.objective]
  for key in objective.reward:
   battle.loot[key] += objective.reward[key]
  battle.objectiveAwarded = true
  s.objectivesCompleted += 1
  objective_name = objective.name
 var rescued = battle.get("rescue") if won else null
 if rescued!=null:
  s.specialists[rescued] = true
  add_log(SPECIALISTS[rescued].name+" arrives in Gravehold.")
 s.lastExpedition = {"won":won,"wave":battle.wave,"loot":battle.loot.duplicate(true),"report":report(won),"objective":objective_name,"rescue":rescued}
 if won:
  secure_loot(battle.loot)
  add_log("Returned safely with %d gold." % battle.loot.gold)
 else:
  s.heroDead = true
  add_log("The hero fell. Unsecured rewards were lost.")
 record_run(won,int(battle.wave),battle.loot,battle)
 battle = {}
 s.choices = null
 risk_cache.clear()
 expedition_finished.emit()

func extract() -> bool:
 if battle.is_empty() or not battle.checkpoint:
  return false
 finish(true)
 return true

func forecast(c: Dictionary) -> int:
 # Clone state and use an independent RNG: forecasts never advance real RNG or saves.
 var cache_key = JSON.stringify([hero_stats(),s.recruits,c,s.objective])
 if risk_cache.has(cache_key):
  return risk_cache[cache_key]
 var wins = 0
 for trial in range(24):
  var sim = GraveholdModel.new()
  sim.s = s.duplicate(true)
  sim.simulating = true
  sim.rng.seed = abs(hash(cache_key+str(trial)))
  var setup = c.duplicate(true)
  setup.objective = s.objective
  sim.start_battle(setup)
  for beat in range(750):
   if sim.battle.has("result"):
    break
   if sim.battle.checkpoint:
    sim.continue_battle()
   sim.tick_battle()
  if sim.battle.get("result","")=="win":
   wins += 1
 var result = roundi((wins/24.0*100)/5.0)*5
 if risk_cache.size()>40:
  risk_cache.clear()
 risk_cache[cache_key] = result
 return result

func start_queue(difficulty: String, count: int, at: float = -1) -> bool:
 if locked() or s.heroDead or not s.clearedDungeons.has(difficulty):
  return false
 if at<0:
  at = now_ms()
 s.offlineQueue = {"dungeon":s.clearedDungeons[difficulty].duplicate(true),"remaining":clampi(count,1,3),"readyAt":at+300000}
 return true

func resolve_queue(at: float) -> void:
 while s.offlineQueue!=null and at>=s.offlineQueue.readyAt:
  var q = s.offlineQueue
  var sim = GraveholdModel.new()
  sim.s = s.duplicate(true)
  sim.simulating = true
  sim.rng.seed = rng.randi()
  var setup = q.dungeon.duplicate(true)
  setup.queued = true
  setup.objective = "none"
  sim.start_battle(setup)
  for beat in range(750):
   if sim.battle.has("result"):
    break
   if sim.battle.checkpoint:
    sim.continue_battle()
   sim.tick_battle()
  var won = sim.battle.get("result","")=="win"
  var loot = sim.battle.loot.duplicate(true)
  for key in ["gold"]+RESOURCES+MATERIALS:
   loot[key] = floori(loot[key]*.5)
  if rng.randf()>=.5:
   loot.blueprints = 0
  loot.equipment = loot.equipment.filter(func(_item): return rng.randf()<.5)
  for index in range(s.recruits.size()):
   s.recruits[index].dead = sim.s.recruits[index].dead
  if won:
   secure_loot(loot)
  else:
   s.heroDead = true
  record_run(won,int(sim.battle.wave),loot,q.dungeon)
  s.lastExpedition = {"won":won,"wave":sim.battle.wave,"loot":loot,"report":sim.report(won),"objective":null,"rescue":null}
  add_log("Queued expedition returned with half rewards." if won else "Queued expedition failed. Your hero needs revival.")
  q.remaining -= 1
  q.readyAt += 300000
  if not won or q.remaining<=0:
   s.offlineQueue = null
  risk_cache.clear()

func specialist_service(key: String) -> bool:
 if locked() or not s.specialists.get(key,false):
  return false
 if key=="blacksmith":
  if s.buildings.has("workshop") or not pay(WORKSHOP_COST):
   return false
  s.buildings.workshop = 1
 elif key=="quartermaster":
  if s.quartermasterRun==s.expeditions or s.food+25>cap("food") or not pay({"gold":20}):
   return false
  s.food += 25
  s.quartermasterRun = s.expeditions
 elif key=="scout":
  if not pay({"gold":20}):
   return false
  s.choices = null
  choices()
 else:
  return false
 return true

func prestige_reward() -> int:
 return 3+int(s.cycleBosses)*2

func prestige() -> bool:
 if locked() or s.cycleBosses<1 or s.debt+s.interest>0:
  return false
 var meta = {"prestiges":s.meta.prestiges+1,"essence":s.meta.essence+prestige_reward()}
 var talents = s.talents.duplicate(true)
 var history = s.history.duplicate(true)
 var disabled = s.tutorialsDisabled
 var seen = s.seen.duplicate()
 reset()
 s.meta = meta
 s.talents = talents
 s.history = history
 s.tutorialsDisabled = disabled
 s.seen = seen
 return true

func buy_talent(key: String) -> bool:
 if locked() or not s.talents.has(key) or s.talents[key]>=5:
  return false
 var cost = 1+s.talents[key]
 if s.meta.essence<cost:
  return false
 s.meta.essence -= cost
 s.talents[key] += 1
 risk_cache.clear()
 return true
