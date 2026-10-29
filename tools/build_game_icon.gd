extends SceneTree

## Packaging the approved artwork only; no visual redesign or color changes.
func _initialize() -> void:
	var original := Image.load_from_file("res://assets/branding/haohaochifan-master-v3.png")
	if original == null:
		push_error("Approved game icon master is missing")
		quit(1)
		return
	var sizes := [16, 32, 48, 64, 128, 144, 180, 256, 512, 1024]
	var entries: Array[PackedByteArray] = []
	var ico_sizes := [16, 32, 48, 64, 128, 256]
	for size in sizes:
		var scaled := original.duplicate() as Image
		scaled.convert(Image.FORMAT_RGBA8)
		scaled.resize(size, size, Image.INTERPOLATE_LANCZOS)
		if scaled.save_png("res://assets/branding/haohaochifan-%d.png" % size) != OK:
			quit(1)
			return
		if size in ico_sizes: entries.append(scaled.save_png_to_buffer())
	var file := FileAccess.open("res://assets/branding/haohaochifan.ico", FileAccess.WRITE)
	file.store_16(0)
	file.store_16(1)
	file.store_16(ico_sizes.size())
	var offset := 6 + 16 * ico_sizes.size()
	for i in ico_sizes.size():
		var size: int = ico_sizes[i]
		file.store_8(0 if size == 256 else size)
		file.store_8(0 if size == 256 else size)
		file.store_8(0)
		file.store_8(0)
		file.store_16(1)
		file.store_16(32)
		file.store_32(entries[i].size())
		file.store_32(offset)
		offset += entries[i].size()
	for entry in entries: file.store_buffer(entry)
	file.close()
	print("GAME_ICON_BUILT=" + JSON.stringify({"png_sizes": sizes, "ico_sizes": ico_sizes}))
	quit()
