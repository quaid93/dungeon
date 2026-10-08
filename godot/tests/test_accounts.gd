extends SceneTree
const Client = preload("res://scripts/account_client.gd")
var failures: Array[String] = []
var checks = 0
var loaded: Variant = null
func _initialize() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
 checks += 1
 if not value: failures.append(title)
func wait_request(client: Node) -> void:
 var deadline = Time.get_ticks_msec()+15000
 while client.busy and Time.get_ticks_msec()<deadline: await process_frame
 check(not client.busy,"account request completes")
func run() -> void:
 var endpoint = OS.get_cmdline_user_args()[0]
 var first = Client.new()
 root.add_child(first)
 check(not first.authenticate("native@example.com","Native-test-2026",true,"http://example.com"),"remote credentials require HTTPS")
 check(first.authenticate("native@example.com","Native-test-2026",true,endpoint),"native registration starts")
 await wait_request(first)
 check(first.email=="native@example.com" and not first.cookie.is_empty(),"native session receives HTTP-only cookie")
 first.sync({"wood":123,"native_test":true})
 first.sync({"wood":456,"native_test":true})
 await wait_request(first)
 var second = Client.new()
 root.add_child(second)
 second.account_loaded.connect(func(data): loaded=data)
 second.authenticate("native@example.com","Native-test-2026",false,endpoint)
 await wait_request(second)
 check(loaded is Dictionary and loaded.get("wood")==456,"another desktop receives latest queued server save")
 second.logout()
 await wait_request(second)
 check(second.cookie.is_empty() and second.email.is_empty(),"logout clears memory session")
 print("Native account checks: %d passed, %d failed" % [checks-failures.size(),failures.size()])
 for failure in failures: printerr("FAIL: "+failure)
 first.queue_free()
 second.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
