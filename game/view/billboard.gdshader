// Horde/tower billboard sprite (D-087). Camera-facing quad pivoted at the instance
// origin (bottom-centre). INSTANCE_CUSTOM.r = frame offset, .g = flip (0 or 1).
// The walk frame comes from TIME: cosmetic, so it stays in the view.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec2 sprite_size = vec2(1.0);
uniform int frames = 1;
uniform float fps = 0.0;

varying flat float v_frame;
varying flat float v_flip;

void vertex() {
	// Same as a StandardMaterial3D with billboard enabled; the shader sizes the quad.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.xy *= sprite_size;
	v_frame = float((int(INSTANCE_CUSTOM.r) + int(TIME * fps)) % frames);
	v_flip = INSTANCE_CUSTOM.g;
}

void fragment() {
	float u = v_flip > 0.5 ? 1.0 - UV.x : UV.x;
	vec4 c = texture(tex, vec2((v_frame + u) / float(frames), UV.y));
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;  // opaque cut-out: depth-tested, no sorting
}
