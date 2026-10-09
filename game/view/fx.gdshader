// Combat effect disc (D-120): camera-facing quad, size from the instance basis scale,
// colour and alpha from the MultiMesh instance colour. Soft round edge, alpha blended.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * (1.0 - smoothstep(0.7, 1.0, d));
}
