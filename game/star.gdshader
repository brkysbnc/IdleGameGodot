shader_type spatial;
render_mode unshaded;

void fragment() {
	float grain = sin(UV.x * 93.0 + sin(UV.y * 61.0 + TIME * 0.3) * 2.0);
	float bands = sin(UV.y * 57.0 + grain * 0.7 + TIME * 0.2) * 0.5 + 0.5;
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.0);
	ALBEDO = mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.88, 0.53), bands * 0.5 + rim * 0.4);
}
