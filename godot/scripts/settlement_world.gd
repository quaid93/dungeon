class_name GraveholdSettlementWorld
extends Control
## Walkable settlement; feet positions and collisions use a fixed logical map.
signal interacted(station: String)
const MAP = Vector2(1100,640)
const SPEED = 190.0
const REACH = 100.0
const STATIONS = {
 "wood":{"name":"Woodcutting camp","point":Vector2(185,180)},
 "stone":{"name":"Stone quarry","point":Vector2(870,180)},
 "food":{"name":"Homestead","point":Vector2(175,460)},
 "barracks":{"name":"Barracks","point":Vector2(870,465)},
 "forge":{"name":"Blacksmith","point":Vector2(540,175)},
 "camp":{"name":"Campfire","point":Vector2(535,420)},
 "gate":{"name":"Dungeon gate","point":Vector2(1010,320)},
 "treasury":{"name":"Quartermaster","point":Vector2(350,340)}
}
var model: GraveholdModel
var hero_position = Vector2(535,535)
var destination = Vector2.ZERO
var walking_to = false
var pending_station = ""
var can_move: Callable
var elapsed = 0.0
var moving = false
var font: Font
var followers: Array[Vector2] = []
var navigation = AStarGrid2D.new()
var route = PackedVector2Array()

func _ready() -> void:
 custom_minimum_size = Vector2(0,600)
 size_flags_horizontal = Control.SIZE_EXPAND_FILL
 mouse_filter = Control.MOUSE_FILTER_STOP
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 font = ThemeDB.fallback_font
 navigation.region = Rect2i(0,0,37,22)
 navigation.cell_size = Vector2(30,30)
 navigation.offset = Vector2(15,15)
 navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
 navigation.update()
 for x in range(37):
  for y in range(22):
   var point = Vector2(x*30+15,y*30+15)
   navigation.set_point_solid(Vector2i(x,y),blocked(point) or point.x<35 or point.x>MAP.x-35 or point.y<85 or point.y>MAP.y-30)
 for i in range(3): followers.append(hero_position+Vector2(-35-i*25,25))

func blocked(point: Vector2) -> bool:
 for key in ["wood","stone","food","barracks","forge"]:
  var p: Vector2 = STATIONS[key].point
  if Rect2(p-Vector2(65,85),Vector2(130,90)).has_point(point): return true
 return false

func move_hero(direction: Vector2, delta: float) -> void:
 var next = hero_position+direction.limit_length()*SPEED*delta
 next = next.clamp(Vector2(35,85),MAP-Vector2(35,30))
 var before = hero_position
 if not blocked(Vector2(next.x,hero_position.y)): hero_position.x = next.x
 if not blocked(Vector2(hero_position.x,next.y)): hero_position.y = next.y
 moving = hero_position.distance_to(before)>.01

func nearest_station() -> String:
 var nearest = ""
 var distance = REACH
 for key in STATIONS:
  var d = hero_position.distance_to(STATIONS[key].point+Vector2(0,25))
  if d<distance:
   nearest = key
   distance = d
 return nearest

func interact_nearby() -> void:
 var key = nearest_station()
 if not key.is_empty():
  walking_to = false
  pending_station = ""
  interacted.emit(key)

func walk_to(point: Vector2) -> void:
 destination = point.clamp(Vector2(35,85),MAP-Vector2(35,30))
 pending_station = ""
 for key in STATIONS:
  if point.distance_to(STATIONS[key].point)<75:
   pending_station = key
   destination = STATIONS[key].point+Vector2(0,55)
   break
 route = navigation.get_point_path(Vector2i(hero_position/30),Vector2i(destination/30))
 if route.is_empty():
  walking_to = false
  pending_station = ""
  return
 route.append(destination)
 walking_to = true

func _gui_input(event: InputEvent) -> void:
 if can_move.is_valid() and not can_move.call(): return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  walk_to(event.position/size*MAP)
  accept_event()

func _input(event: InputEvent) -> void:
 if can_move.is_valid() and not can_move.call(): return
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
  interact_nearby()
  get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
 elapsed += delta
 moving = false
 if model==null: return
 if not can_move.is_valid() or can_move.call():
  var direction = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
  if direction.length()>0:
   walking_to = false
   pending_station = ""
  elif walking_to:
   while not route.is_empty() and hero_position.distance_to(route[0])<6:
    route.remove_at(0)
   var offset = route[0]-hero_position if not route.is_empty() else Vector2.ZERO
   if route.is_empty():
    walking_to = false
    if not pending_station.is_empty(): interact_nearby()
   else: direction = offset.normalized()
  move_hero(direction,delta)
 for i in range(followers.size()):
  var target = hero_position+Vector2(-40-i*25,25)
  if followers[i].distance_to(target)>10: followers[i] = followers[i].move_toward(target,SPEED*.8*delta)
 queue_redraw()

func caption(value: String, p: Vector2, color: Color = Color("d9c697"), font_size: int = 13) -> void:
 var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
 draw_string(font,p-Vector2(width/2,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func tree(p: Vector2, tint: Color = Color("34443e")) -> void:
 draw_rect(Rect2(p+Vector2(-5,-6),Vector2(10,35)),Color("574638"))
 for i in range(3):
  draw_colored_polygon(PackedVector2Array([p+Vector2(0,-65+i*20),p+Vector2(-30-i*4,-15+i*20),p+Vector2(30+i*4,-15+i*20)]),tint)

func building(key: String) -> void:
 var p: Vector2 = STATIONS[key].point
 var built = model.s.buildings.has(key) if key!="forge" else model.s.buildings.has("workshop")
 var height = 60+mini(int(model.s.buildings.get(key+"Storage",0)),5)*5
 draw_ellipse_shadow(p,Vector2(145,28))
 if not built:
  draw_rect(Rect2(p-Vector2(55,50),Vector2(110,55)),Color("4f4c45"),false,2)
  for side in [-1,1]:
   draw_rect(Rect2(p+Vector2(side*55-3,-55),Vector2(6,65)),Color("8e7960"))
  draw_line(p+Vector2(-55,-48),p+Vector2(55,0),Color("8e7960"),3)
  caption("Construction site",p+Vector2(0,-70),Color("9caa9c"),11)
 else:
  draw_rect(Rect2(p-Vector2(55,height),Vector2(110,height)),Color("686759") if key=="stone" else Color("675748"))
  for x in range(-48,55,18): draw_line(p+Vector2(x,-height),p+Vector2(x,0),Color("4f463f"),2)
  draw_colored_polygon(PackedVector2Array([p+Vector2(-70,-height),p+Vector2(0,-height-40),p+Vector2(70,-height)]),Color("343743"))
  draw_line(p+Vector2(-70,-height),p+Vector2(0,-height-40),Color("646373"),3)
  draw_rect(Rect2(p+Vector2(-12,-32),Vector2(24,32)),Color("172227"))
  for x in [-37,25]:
   draw_rect(Rect2(p+Vector2(x,-42),Vector2(13,18)),Color("dab879"))
  if key=="forge":
   draw_rect(Rect2(p+Vector2(32,-height-40),Vector2(16,45)),Color("797a78"))
   draw_circle(p+Vector2(40,-height-55-sin(elapsed)*5),12,Color(.5,.5,.52,.3))
  if model.s.buildings.get(key+"Storage",0)>0:
   draw_rect(Rect2(p+Vector2(60,-25),Vector2(25,25)),Color("8a7050"))
   draw_line(p+Vector2(60,-12),p+Vector2(85,-12),Color("b39a6c"),2)
 if model.s.workers.has(key):
  var role = {"wood":"Woodcutter","stone":"Miner","food":"Farmer"}.get(key,"Miner")
  var offset = Vector2(85+sin(elapsed*.8)*12,30)
  draw_texture_rect(GraveholdArt.character(role,model),Rect2(p+offset-Vector2(15,40),Vector2(30,40)),false)
 caption(STATIONS[key].name,p+Vector2(0,65))

func draw_ellipse_shadow(p: Vector2, dimensions: Vector2) -> void:
 draw_set_transform(p*size/MAP,0,Vector2(dimensions.x/dimensions.y,1)*size/MAP)
 draw_circle(Vector2.ZERO,dimensions.y/2,Color(0,0,0,.23))
 draw_set_transform(Vector2.ZERO,0,size/MAP)

func _draw() -> void:
 if model==null or font==null: return
 draw_set_transform(Vector2.ZERO,0,size/MAP)
 draw_rect(Rect2(Vector2.ZERO,MAP),Color("25342e"))
 for x in range(15,1100,43):
  for y in range(20,640,37):
   var p = Vector2(x+(y%13),y)
   draw_line(p,p+Vector2(3,-5),Color("35473a"),2)
 # Paths connect every profession to the gathering square and dungeon gate.
 for key in STATIONS:
  draw_line(Vector2(535,340),STATIONS[key].point+Vector2(0,40),Color("4d4940"),44)
  draw_line(Vector2(535,340),STATIONS[key].point+Vector2(0,40),Color("5b5547"),30)
 for x in range(20,1100,60):
  tree(Vector2(x,62),Color("1a2927"))
  tree(Vector2(x,635),Color("1b302b"))
 for p in [Vector2(65,210),Vector2(100,250),Vector2(255,205),Vector2(280,170)]: tree(p)
 for i in range(6):
  var p = Vector2(765+i%3*35,200+i/3*24)
  draw_colored_polygon(PackedVector2Array([p+Vector2(-15,8),p+Vector2(-10,-10),p+Vector2(8,-17),p+Vector2(20,4)]),Color("6b777a"))
 for i in range(5):
  draw_rect(Rect2(85,380+i*11,170,5),Color("6b6047"))
  for x in range(90,250,19): draw_line(Vector2(x,380+i*11),Vector2(x+2,373+i*11),Color("a3a069"),3)
 for key in ["wood","stone","food","barracks","forge"]: building(key)
 var gate: Vector2 = STATIONS.gate.point
 draw_rect(Rect2(gate-Vector2(45,80),Vector2(90,95)),Color("75717c"))
 draw_rect(Rect2(gate-Vector2(28,62),Vector2(56,77)),Color("111922"))
 for i in range(5): draw_line(gate+Vector2(-24+i*12,-58),gate+Vector2(-24+i*12,12),Color("4c4858"),3)
 caption("Dungeon gate",gate+Vector2(0,65))
 var fire: Vector2 = STATIONS.camp.point
 draw_circle(fire,27,Color("686458"))
 draw_circle(fire,21,Color("242827"))
 draw_line(fire+Vector2(-14,6),fire+Vector2(12,-4),Color("9b704b"),7)
 draw_colored_polygon(PackedVector2Array([fire+Vector2(-12,4),fire+Vector2(0,-27-sin(elapsed*5)*4),fire+Vector2(13,6)]),Color("eaaa60"))
 caption("Campfire",fire+Vector2(0,65))
 var quarter: Vector2 = STATIONS.treasury.point
 draw_texture_rect(GraveholdArt.character("Farmer",model),Rect2(quarter-Vector2(18,46),Vector2(36,46)),false)
 caption("Quartermaster",quarter+Vector2(0,65))
 for i in range(model.s.recruits.size()):
  if model.s.recruits[i].dead: continue
  var p = followers[mini(i,2)] if not model.locked() else STATIONS.barracks.point+Vector2(i*30,35)
  draw_texture_rect(GraveholdArt.character(model.s.recruits[i].cls,model),Rect2(p-Vector2(13,34),Vector2(26,34)),false)
 draw_ellipse_shadow(hero_position,Vector2(38,12))
 draw_texture_rect(GraveholdArt.character("hero",model),Rect2(hero_position-Vector2(23,59)+Vector2(0,sin(elapsed*12)*2 if moving else 0),Vector2(46,59)),false)
 var nearby = nearest_station()
 if not nearby.is_empty():
  var p: Vector2 = STATIONS[nearby].point
  draw_arc(p+Vector2(0,25),40,0,TAU,32,Color("dac38b"),2)
  caption("E · "+STATIONS[nearby].name,Vector2(550,55),Color("f5dfaa"),15)
 if walking_to:
  draw_arc(destination,8,0,TAU,20,Color("dac38b"),2)
 if model.s.gather!=null:
  var key = model.s.gather.kind
  var left = maxi(0,ceili((model.s.gather.end-GraveholdModel.now_ms())/1000))
  caption("Ready to collect" if left==0 else "Gathering · %ds" % left,STATIONS[key].point+Vector2(0,85),Color("add194"))
 caption("WASD / arrows to move · E to interact · click a building to walk there",Vector2(550,28),Color("b9c9b9"),14)
 draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
