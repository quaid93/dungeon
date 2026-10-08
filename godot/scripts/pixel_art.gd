class_name GraveholdArt
extends RefCounted
static var cache: Dictionary = {}
const RARITY_COLORS = {"common":Color("aeb8c5"),"uncommon":Color("8fb78c"),"rare":Color("7aaff2"),"epic":Color("bc90e5"),"legendary":Color("edd082")}

static func texture(path: String) -> Texture2D:
 if not cache.has(path):
  cache[path] = load(path)
 return cache[path]

static func character(kind: String, model: GraveholdModel) -> Texture2D:
 if kind=="hero":
  kind = "hero_%d%d%d" % [1 if model.s.gear.body>=0 else 0,1 if model.s.gear.weapon>=0 else 0,1 if model.s.gear.head>=0 else 0]
 return texture("res://assets/sprites/"+kind+".svg")

static func item(key: String, tier: int, rarity: String = "common") -> Texture2D:
 if not RARITY_COLORS.has(rarity):
  rarity = "common"
 return texture("res://assets/items/%s_%d_%s.svg" % [key,clampi(tier,-1,4),rarity])
