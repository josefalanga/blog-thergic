shader_type canvas_item;

// Every ball is packed in one vec4: .xy is its position (viewport pixels),
// .z its radius, and .w the index of its color in the palette below. Godot
// hands us the array every frame, and active_balls says how many slots are
// really alive so dead ones cost nothing.
uniform vec4 balls[16];
uniform int active_balls = 0;

// The small set of colors balls can be. Picking from a palette instead of
// sending a full color per ball keeps the uniforms tiny.
uniform vec3 palette[4];
const int PALETTE_SIZE = 4;

// The magic number from the article. Pixels whose field clears this become blob,
// the rest become background. Lower it and blobs get greedy and merge, raise it
// and they get shy and stay as separate circles.
uniform float threshold : hint_range(0.0, 1.0) = 0.5;

vec3 ball_color(int i) {
	return palette[int(balls[i].w) % PALETTE_SIZE];
}

void fragment() {
	// FRAGCOORD.xy is the pixel we're drawing right now, in viewport coordinates.
	vec2 pos = FRAGCOORD.xy;

	// Add the pull of every ball on this pixel. That sum is our field, the same
	// idea as the radial gradients added together in the Photopea experiment.
	// We also gather color the same way, weighted by each ball's contribution,
	// so two blobs that merge end up blending their colors.
	float field = 0.0;
	vec3 color = vec3(0.0);
	for (int i = 0; i < active_balls; i++) {
		float r = balls[i].z;
		vec2 to_ball = pos - balls[i].xy;
		float d2 = dot(to_ball, to_ball);

		// Outside the ball's radius there's nothing to add, so skip ahead and
		// save the division below. This is the check that keeps far balls cheap.
		if (d2 >= r * r)
			continue;

		// Classic metaball falloff: 1 at the center, smoothly dying to 0 at the
		// ball's edge. Squaring it twice gives that organic look where close
		// balls "bridge" into each other instead of just overlapping.
		float t = max(0.0, 1.0 - d2 / (r * r));
		float contrib = t * t;
		field += contrib;
		color += ball_color(i) * contrib;
	}

	// Normalize the gathered color: divide by the total field so the blob takes
	// the color of whatever ball dominates that pixel. Overlap areas mix.
	color = field > 0.0 ? color / field : vec3(1.0);

	// Threshold time. step() returns 1 when the field clears the threshold, 0
	// otherwise, so blobs come out colored and everything else transparent.
	float alpha = step(threshold, field);
	COLOR = vec4(color, alpha);
}
