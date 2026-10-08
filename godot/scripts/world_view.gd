class_name GraveholdWorldView
extends Control
## Native CanvasItem rendering. Character sizes intentionally center the hero.
var model: GraveholdModel
var mode = "battle"
var elapsed = 0.0
var beat_age = 1.0
var last_beat = -1
var font: Font

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 font = ThemeDB.fallback_font
 custom_minimum_size = Vector2(0,330 if mode=="battle" else 220)

func _process(delta: float) -> void:
 elapsed += delta
 beat_age += delta
 if model!=null and not model.battle.is_empty():
  if int(model.battle.beat)!=last_beat:
   last_beat = int(model.battle.beat)
   beat_age = 0
 if mode=="battle":
  queue_redraw()

func text_at(value: String, point: Vector2, size_px: int = 12, color: Color = Color("c6cbd4")) -> void:
 draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func center_text(value: String, center: Vector2, size_px: int, color: Color) -> void:
 var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
 text_at(value,center-Vector2(width/2,0),size_px,color)

func _draw() -> void:
 if model==null or font==null:
  return
 if mode=="battle":
  draw_crypt()
  if model.battle.is_empty():
   return
  var ground = size.y*.8
  var hero_x = size.x*.39
  var allies = model.battle.allies
  for index in range(1,allies.size()):
   draw_unit(allies[index],Vector2(hero_x-160+(index-1)*46,ground),Vector2(42,53),false)
  draw_unit(allies[0],Vector2(hero_x,ground),Vector2(138,173),false)
  var enemies = model.battle.enemies
  for index in range(enemies.size()):
   var boss = enemies[index].role=="Boss"
   draw_unit(enemies[index],Vector2(size.x*.69+index*72,ground),Vector2(88,110) if boss else Vector2(58,73),true)
 elif mode=="settlement":
  draw_settlement()

func draw_crypt() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("191e2c"))
 for y in range(0,int(size.y*.8),40):
  draw_line(Vector2(0,y),Vector2(size.x,y),Color("2c3040"),1)
  for x in range(0,int(size.x),85):
   draw_line(Vector2(x+(42 if y%80 else 0),y),Vector2(x+(42 if y%80 else 0),y+40),Color("2c3040"),1)
 for x in [.18,.49,.8]:
  var center = Vector2(size.x*x,size.y*.39)
  var radius = size.y*.23
  draw_circle(center,radius+9,Color("484656"))
  draw_rect(Rect2(center.x-radius-9,center.y,(radius+9)*2,size.y*.8-center.y),Color("484656"))
  draw_circle(center,radius,Color("0d121e"))
  draw_rect(Rect2(center.x-radius,center.y,radius*2,size.y*.8-center.y),Color("0d121e"))
 draw_rect(Rect2(0,size.y*.8,size.x,size.y*.2),Color("2b2937"))
 for y in [size.y*.82,size.y*.91]:
  draw_line(Vector2(0,y),Vector2(size.x,y),Color("574957"),2)
 for x in [.08,.92]:
  var p = Vector2(size.x*x,size.y*.38)
  for radius in [55,38,23]:
   draw_circle(p,radius,Color(1,.65,.25,.025))
  draw_rect(Rect2(p+Vector2(-3,7),Vector2(6,33)),Color("785948"))
  draw_colored_polygon(PackedVector2Array([p+Vector2(0,-21),p+Vector2(-9,2),p+Vector2(0,13),p+Vector2(9,2)]),Color("e9a052"))
  draw_colored_polygon(PackedVector2Array([p+Vector2(0,-9),p+Vector2(-4,4),p+Vector2(0,9),p+Vector2(4,4)]),Color("ffe2a1"))

func draw_unit(unit: Dictionary, base: Vector2, dimensions: Vector2, hostile: bool) -> void:
 var dead = unit.hp<=0
 var hero = unit.role=="Hero"
 var event = unit.get("event",{})
 var active = not dead and not model.battle.checkpoint and model.battle.phase=="combat" and event.get("beat",-2)==model.battle.beat and beat_age<.5
 var shift = sin(beat_age/.5*PI)*11*( -1 if hostile else 1) if active and event.get("kind","")=="attack" else 0
 var pos = base-Vector2(dimensions.x/2,dimensions.y)+Vector2(shift,0)
 var tint = Color(1,1,1,.28 if dead else 1)
 if active and event.get("kind","")=="damage":
  tint = Color(1.4,.75,.75,1)
 var rect = Rect2(pos,dimensions)
 var tex = GraveholdArt.character(unit.kind,model)
 if hostile:
  rect.position.x += dimensions.x
  rect.size.x *= -1
 draw_texture_rect(tex,rect,false,tint)
 var title = "YOUR HERO" if hero else unit.name
 center_text(title,base-Vector2(0,dimensions.y+12),11 if hero else 9,Color("dcc08a") if hero else Color("c6cbd4"))
 var hp_width = 128 if hero else dimensions.x
 draw_rect(Rect2(base.x-hp_width/2,base.y+4,hp_width,6 if hero else 4),Color("0e121b"))
 draw_rect(Rect2(base.x-hp_width/2,base.y+4,hp_width*maxf(0,unit.hp/float(unit.maxHp)),6 if hero else 4),Color("ba7479") if hostile else Color("91b789"))
 center_text("%d / %d%s" % [ceil(unit.hp),unit.maxHp," HP" if hero else ""],base+Vector2(0,26),12 if hero else 9,Color("dfd3ab") if hero else Color("a7b3c0"))
 if active:
  var color = Color("a5d79f") if event.kind=="heal" else Color("f0c691") if event.kind=="attack" else Color("ed9995")
  center_text(str(event.text),base-Vector2(0,dimensions.y+25+beat_age*35),16 if hero else 11,color)
 if dead:
  center_text("Fallen",base+Vector2(0,41),9,Color("90959d"))

func draw_settlement() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("27343a"))
 draw_rect(Rect2(0,size.y*.65,size.x,size.y*.35),Color("202d29"))
 draw_circle(Vector2(size.x*.86,42),18,Color("898b77"))
 var keys = ["wood","stone","food","barracks"]
 for index in range(4):
  var key = keys[index]
  var x = size.x*(.14+index*.24)
  var floor_y = size.y*.83
  var built = model.s.buildings.has(key)
  var level = int(model.s.buildings.get(key+"Storage",0))
  var height = 48+mini(level,5)*5
  var color = [Color("70624a"),Color("677480"),Color("73774f"),Color("6e597b")][index]
  var alpha = 1 if built else .3
  color.a = alpha
  draw_rect(Rect2(x-38,floor_y-height,76,height),color,built,-1 if built else 1)
  draw_colored_polygon(PackedVector2Array([Vector2(x-48,floor_y-height),Vector2(x,floor_y-height-31),Vector2(x+48,floor_y-height)]),Color(.25,.28,.34,alpha))
  if built:
   draw_rect(Rect2(x-10,floor_y-30,20,30),Color("151d25"))
   draw_rect(Rect2(x-28,floor_y-38,8,10),Color("d6b879"))
   draw_rect(Rect2(x+20,floor_y-38,8,10),Color("d6b879"))
   if level>=2:
    draw_rect(Rect2(x+40,floor_y-45,12,45),Color("797a64"))
   if level>=4:
    draw_rect(Rect2(x-25,floor_y-height-25,7,25),Color("7c7968"))
  center_text(["WOODCUTTING","QUARRY","HOMESTEAD","BARRACKS"][index],Vector2(x,27),10,Color("d6c18e"))
  center_text("Not built" if not built else "%d companions" % model.s.recruits.size() if key=="barracks" else "Storage level %d" % level,Vector2(x,floor_y+24),10,Color("a9b4ae"))
  if model.s.workers.has(key):
   draw_texture_rect(GraveholdArt.character({"wood":"Woodcutter","stone":"Miner","food":"Farmer"}[key],model),Rect2(x+38,floor_y-32,26,33),false)
  if key=="barracks":
   for i in range(model.s.recruits.size()):
    draw_texture_rect(GraveholdArt.character(model.s.recruits[i].cls,model),Rect2(x+24+i*24,floor_y-32,24,30),false)
 var resident_index = 0
 for key in model.s.specialists:
  if model.s.specialists[key]:
   var p = Vector2(18+resident_index*46,40)
   draw_texture_rect(GraveholdArt.character("Miner" if key=="blacksmith" else "Farmer" if key=="quartermaster" else "Archer",model),Rect2(p,Vector2(26,33)),false)
   text_at(GraveholdModel.SPECIALISTS[key].name,p+Vector2(0,45),9,Color("d6c18e"))
   resident_index += 1
