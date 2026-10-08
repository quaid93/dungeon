class_name GraveholdAccountClient
extends Node
## Optional adapter for the existing Node account service. Cookie lives only in memory.
signal status_changed(message: String)
signal account_loaded(data: Variant)
var email = ""
var server_url = "http://127.0.0.1:3000"
var cookie = ""
var busy = false
var request: HTTPRequest
var operation = ""
var queued_save: Variant = null
var sync_status = "LOCAL SAVE"

func _ready() -> void:
 request = HTTPRequest.new()
 request.timeout = 12
 add_child(request)
 request.request_completed.connect(_completed)

func authenticate(address: String, password: String, register: bool, endpoint: String) -> bool:
 if busy:
  return false
 endpoint = endpoint.strip_edges().trim_suffix("/")
 # Plain HTTP is for local development only; production credentials require TLS.
 if not endpoint.begins_with("https://") and not endpoint.begins_with("http://127.0.0.1:") and not endpoint.begins_with("http://localhost:"):
  status_changed.emit("Use HTTPS, or localhost HTTP for development.")
  return false
 server_url = endpoint
 return _send("register" if register else "login",{"email":address,"password":password})

func sync(data: Dictionary) -> void:
 if email.is_empty():
  return
 if busy:
  queued_save = data.duplicate(true)
 else:
  _send("save",{"state":data})

func logout() -> bool:
 if busy:
  status_changed.emit("Wait for the current account request to finish.")
  return false
 queued_save = null
 if not email.is_empty():
  _send("logout",{})
 else:
  _clear_session()
 return true

func _send(kind: String, body: Dictionary) -> bool:
 if busy:
  return false
 busy = true
 operation = kind
 var headers = PackedStringArray(["Content-Type: application/json"])
 if not cookie.is_empty():
  headers.append("Cookie: "+cookie)
 var result = request.request(server_url+"/api/"+kind,headers,HTTPClient.METHOD_POST,JSON.stringify(body))
 if result!=OK:
  busy = false
  sync_status = "SYNC FAILED · LOCAL SAVE SAFE"
  status_changed.emit(error_string(result))
  return false
 return true

func _clear_session() -> void:
 email = ""
 cookie = ""
 queued_save = null
 sync_status = "LOCAL SAVE"

func _completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
 var kind = operation
 busy = false
 operation = ""
 var payload = JSON.parse_string(body.get_string_from_utf8())
 if not payload is Dictionary:
  payload = {}
 if kind=="logout":
  _clear_session()
  status_changed.emit("Signed out. Local guest progress restored.")
  account_loaded.emit(null)
  return
 if result!=HTTPRequest.RESULT_SUCCESS or code<200 or code>=300:
  if code==401 and kind=="save":
   _clear_session()
  sync_status = "SYNC FAILED · LOCAL SAVE SAFE"
  status_changed.emit(str(payload.get("error","Unable to reach the save server. Your local progress is safe.")))
  queued_save = null
  return
 if kind in ["login","register"]:
  for header in headers:
   if header.to_lower().begins_with("set-cookie:"):
    var content = header.substr(header.find(":")+1).strip_edges()
    if content.begins_with("session="):
     cookie = content.split(";")[0]
  if cookie.is_empty():
   status_changed.emit("Server did not return a session.")
   return
  email = payload.get("email","")
  sync_status = "ACCOUNT CONNECTED"
  account_loaded.emit(payload.get("state"))
  status_changed.emit("Signed in as "+email)
 elif kind=="save":
  sync_status = "ACCOUNT SAVE SYNCED"
 if queued_save!=null and not email.is_empty():
  var latest = queued_save
  queued_save = null
  sync(latest)
