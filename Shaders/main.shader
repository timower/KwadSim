shader_type canvas_item;

uniform float distortion;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
    uv = uv * 2.0 - 1.0;
    
    float r = uv.x * uv.x + uv.y * uv.y;
	//float add = 1f;
    uv *=  1f + distortion  * r;
	uv /= (1f + distortion * 2.0f);
	//if (abs(uv.x) < 1.0f && abs(uv.y) < 1.0f) {
	    uv = 0.5 * (uv + 1.0);
		vec3 col = texture(TEXTURE, uv).xyz;
		//col *= 1f + (0.2 * sin(SCREEN_UV.y * 50.0f + TIME *0f)) * float(0.1 > rand(vec2(TIME, 0)));
	    COLOR.xyz = col;
	/*} else {
		COLOR.xyz = vec3(1, 0, 0);
	}*/
}