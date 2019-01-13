shader_type canvas_item;

uniform float distortion;
uniform float aspect;

void fragment() {
	float inv_aspect = 1.0f / aspect;
	vec2 uv = UV;
	uv.x = fract(2f * uv.x);
	uv = uv * 2.0 - 1.0;
	uv.y *= -1f;
	
	uv.y /= aspect;
	
	float r = uv.x * uv.x + uv.y * uv.y;
	
	uv *=  1f + distortion  * r;
	//uv /= (1f + distortion * (1f + inv_aspect*inv_aspect));
	
	uv.y *= aspect;
	if (abs(uv.x) < 1.0f && abs(uv.y) < 1.0f) {
		uv = 0.5 * (uv + 1.0);
		vec3 col = texture(TEXTURE, uv).xyz;
		COLOR.xyz = col;
	} else {
		COLOR.xyz = vec3(0, 0, 0);
	}
}