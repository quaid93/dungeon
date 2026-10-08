class_name GraveholdSaveStore
extends RefCounted
## Atomic JSON saves with one previous-good backup. Session credentials never go here.
var path = "user://save.json"
var last_error = ""

func write(data: Dictionary) -> bool:
 var file = FileAccess.open(path+".tmp", FileAccess.WRITE)
 if file == null:
  last_error = "Could not write save: " + error_string(FileAccess.get_open_error())
  return false
 file.store_string(JSON.stringify(data,"\t"))
 file.flush()
 var status = file.get_error()
 file.close()
 if status != OK:
  last_error = "Save write failed: " + error_string(status)
  return false
 var absolute = ProjectSettings.globalize_path(path)
 if FileAccess.file_exists(path):
  var backup_error = DirAccess.copy_absolute(absolute,absolute+".bak")
  if backup_error != OK:
   last_error = "Could not back up existing save."
   return false
 var rename_error = DirAccess.rename_absolute(absolute+".tmp",absolute)
 if rename_error != OK:
  last_error = "Could not install new save: " + error_string(rename_error)
  return false
 last_error = ""
 return true

func read() -> Variant:
 for candidate in [path,path+".bak"]:
  if FileAccess.file_exists(candidate):
   var parser = JSON.new()
   var result = parser.parse(FileAccess.get_file_as_string(candidate))
   var value = parser.data if result==OK else null
   if value is Dictionary:
    if candidate.ends_with(".bak"):
     last_error = "Recovered the previous save from backup."
    return value
 last_error = "No valid local save."
 return null

func import_file(source: String, model: GraveholdModel) -> bool:
 if FileAccess.get_file_as_bytes(source).size()>2000000:
  last_error = "Save file is too large."
  return false
 var value = JSON.parse_string(FileAccess.get_file_as_string(source))
 if not model.load_state(value):
  last_error = model.last_error
  return false
 model.accrue()
 return write(model.serialize())

func export_file(target: String, data: Dictionary) -> bool:
 var file = FileAccess.open(target,FileAccess.WRITE)
 if file == null:
  last_error = "Could not export to that location."
  return false
 file.store_string(JSON.stringify(data,"\t"))
 file.flush()
 var status = file.get_error()
 file.close()
 return status==OK
