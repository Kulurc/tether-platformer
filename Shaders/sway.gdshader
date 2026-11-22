shader_type canvas_item;
// Wind sway done on the GPU: the drawing is made once and cached; this only bends its vertices.
// Used by MeadowTree (`sway`) and MenuHill (`grass_sway`) - no per-frame redraw, almost free.
//   mode 0 (trees): bends more the higher a point is above the node's origin (the trunk base).
//   mode 1 (grass): moves only grass-blade tips (drawn with a marker UV), the ground stays put.
uniform int mode = 0;
uniform float amount = 6.0;   // px of sideways movement at full weight
uniform float speed = 0.2;    // sway cycles per second
uniform float height = 200.0; // mode 0: height (px above the base) that gets the full `amount`
uniform float phase = 0.0;    // offsets the cycle so several trees don't move in lockstep
uniform float flutter = 0.15; // a faster, smaller ripple on top (leaves / blades)

void vertex() {
	float w;
	if (mode == 0) {
		w = clamp(-VERTEX.y / height, 0.0, 1.5);
		w *= w;  // the trunk base stays planted, the crown moves most
	} else {
		w = clamp((0.5 - UV.y) * 4.0, 0.0, 1.0);  // blade tips are drawn with UV.y = 0.25
	}
	float t = TIME * speed * 6.2831853 + phase;
	float s = sin(t + VERTEX.x * (mode == 0 ? 0.004 : 0.02))
		+ flutter * sin(t * 2.7 + VERTEX.x * 0.05 + VERTEX.y * 0.03);
	VERTEX.x += s * amount * w;
}
