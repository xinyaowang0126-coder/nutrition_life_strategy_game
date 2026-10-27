shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
varying vec4 item_color;

void vertex() {
	item_color = COLOR;
}

void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a) * item_color;
}
