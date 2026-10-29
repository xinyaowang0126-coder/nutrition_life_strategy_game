extends SceneTree

## Browser loading art is small and available before the PCK downloads.
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output == "":
		push_error("Provide the final Web export directory with --output=")
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/title_life_scenes.json"))
	DirAccess.make_dir_recursive_absolute(output)
	for scene in data["scenes"]:
		var image := Image.load_from_file(scene["image"])
		if image == null:
			quit(1)
			return
		image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
		if image.save_jpg(output.path_join(scene["web_file"]), 0.85) != OK:
			quit(1)
			return
	var html_path := output.path_join("index.html")
	var html := FileAccess.get_file_as_string(html_path)
	var web_scenes: Array[Dictionary] = []
	for scene in data["scenes"]:
		web_scenes.append({"id": scene["id"], "title": scene["title"], "web_file": scene["web_file"], "mobile_focus_x": scene.get("mobile_focus_x", 0.72)})
	var begin := html.find("/* LIFE_SCENES_BEGIN */")
	var end := html.find("/* LIFE_SCENES_END */")
	if begin < 0 or end < begin:
		push_error("Custom loading shell scene marker missing")
		quit(1)
		return
	html = html.substr(0, begin) + "/* LIFE_SCENES_BEGIN */\nconst LIFE_SCENES = " + JSON.stringify(web_scenes) + ";\n" + html.substr(end)
	var html_file := FileAccess.open(html_path, FileAccess.WRITE)
	html_file.store_string(html)
	html_file.close()
	print("TITLE_WEB_IMAGES=" + str(data["scenes"].size()))
	quit()
