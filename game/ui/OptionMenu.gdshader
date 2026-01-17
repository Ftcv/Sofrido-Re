shader_type canvas_item;

uniform float blur_strenght : hint_range(0.0,6.0) = 3.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_strenght;
	
	vec4 col = texture(TEXTURE, UV) * 0.20;
	col += texture(TEXTURE, UV + vec2( px.x, 0.0)) * 0.15;
	col += texture(TEXTURE, UV + vec2(-px.x, 0.0)) * 0.15;
	col += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.15;
	col += texture(TEXTURE, UV + vec2(0.0, -px.x)) * 0.15;
	col += texture(TEXTURE, UV + vec2( px.x, px.y)) * 0.10;
	col += texture(TEXTURE, UV + vec2(-px.x, px.y)) * 0.10;
	col += texture(TEXTURE, UV + vec2( px.x, -px.y)) * 0.10;
	col += texture(TEXTURE, UV + vec2(-px.x, -px.y)) * 0.10;
	
	COLOR = col;
	
}

