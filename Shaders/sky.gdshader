shader_type canvas_item;
// Sky gradient + sun glow + soft light rays, plus an optional overcast cloud deck. Used by LevelArt.
uniform vec4 top_col : source_color;
uniform vec4 mid_col : source_color;
uniform vec4 horizon_col : source_color;
uniform vec4 sun_col : source_color;
uniform vec2 sun = vec2(0.74, 0.36);
uniform float sun_power = 1.0;
uniform float rays = 0.35;
uniform float ray_time = 0.0;  // slowly shifts the rays (LevelArt sets it; 0 = still)
// overcast: 0 = clear sky (Level1), 1 = a full, heavy cloud deck
uniform float overcast = 0.0;
uniform vec4 cloud_light : source_color = vec4(0.78, 0.8, 0.81, 1.0);
uniform vec4 cloud_dark : source_color = vec4(0.42, 0.46, 0.5, 1.0);
uniform vec2 cloud_offset = vec2(0.0);   // set by LevelArt: camera drift + slow wind
uniform float cloud_scale = 2.4;
float hash(float n){ return fract(sin(n) * 43758.5453); }
float n1(float x){ float i = floor(x); float f = fract(x); f = f*f*(3.0-2.0*f); return mix(hash(i), hash(i+1.0), f); }
// sin-free hash: stays smooth on low-precision (web / Compatibility) GPUs
float h2(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float n2(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h2(i), h2(i+vec2(1,0)), f.x), mix(h2(i+vec2(0,1)), h2(i+vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p){
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++){ v += a * n2(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
void fragment(){
	vec2 uv = UV;
	vec3 c = mix(top_col.rgb, mid_col.rgb, smoothstep(0.0, 0.5, uv.y));
	c = mix(c, horizon_col.rgb, smoothstep(0.45, 0.75, uv.y));
	vec2 d = (uv - sun) * vec2(1.7778, 1.0);
	float r = length(d);
	c += sun_col.rgb * sun_power * (exp(-r * 14.0) * 0.9 + exp(-r * 3.0) * 0.28);
	float ang = atan(d.y, d.x);
	float s = n1(ang * 16.0 + ray_time * 0.6) * 0.6 + n1(ang * 41.0 + 3.0 - ray_time * 0.9) * 0.4;
	s = smoothstep(0.5, 0.95, s);
	c += sun_col.rgb * rays * s * exp(-r * 1.4) * smoothstep(-0.1, 0.5, d.y);
	if (overcast > 0.0) {
		// stretched, layered cloud deck: thick near the top, thinning toward the horizon
		vec2 p = vec2(uv.x * 1.7778, uv.y * 2.6) * cloud_scale + cloud_offset;
		float f = fbm(p);
		float f2 = fbm(p * 2.1 + vec2(5.0, 1.0) + f);
		float dens = smoothstep(0.32, 0.72, f * 0.65 + f2 * 0.45) * overcast;
		dens *= 1.0 - smoothstep(0.35, 0.78, uv.y) * 0.75;
		// heavier, darker bellies; lighter tops
		vec3 cc = mix(cloud_light.rgb, cloud_dark.rgb, smoothstep(0.35, 0.85, f2) * 0.85 + uv.y * 0.15);
		c = mix(c, cc, clamp(dens, 0.0, 0.95));
		// light the sun-side edges a touch
		c += sun_col.rgb * sun_power * 0.25 * exp(-r * 4.0) * (1.0 - dens);
	}
	COLOR = vec4(c, 1.0);
}
