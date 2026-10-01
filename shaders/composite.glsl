// Final in-tank composite: the waterline and the underside of the surface,
// the air gap under the lid, a glass-tap ripple, edge refraction and grain.
extern Image surfaceTex;   // r = height offset, b = slope (0.5 = flat)
extern float frontY;       // waterline at the front glass
extern float backY;        // surface at the back glass
extern vec3 airColor;
extern float lamp;
extern vec3 lightColor;
extern float lightI;
extern float time;
extern vec2 size;
extern vec4 tap;           // x, y, age (s), strength
extern float aberration;
extern float grain;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 sampleScene(Image scene, vec2 uv) {
    // Thick-glass refraction: channels separate toward the edges
    vec2 c = uv - 0.5;
    float r2 = dot(c, c);
    vec2 o = c * r2 * aberration;
    return vec3(Texel(scene, uv + o).r, Texel(scene, uv).g, Texel(scene, uv - o).b);
}

vec4 effect(vec4 vcolor, Image scene, vec2 tc, vec2 sc) {
    vec2 uv = tc;

    // A tap on the glass: an expanding ring bends the view for a moment
    if (tap.w > 0.0) {
        vec2 d = sc - tap.xy;
        float r = length(d);
        float ring = tap.z * 560.0;
        float k = exp(-pow((r - ring) / 34.0, 2.0)) * tap.w * exp(-tap.z * 2.5);
        uv += (d / max(r, 1.0)) * k * 7.0 / size;
    }

    vec4 surf = Texel(surfaceTex, vec2(sc.x / size.x, 0.5));
    float off = (surf.r - 0.5) * 32.0;
    float slope = (surf.b - 0.5) / 4.0;
    float front = frontY + off;
    float back = backY + off * 0.55;

    vec3 col;
    if (sc.y < front) {
        // The air gap under the lid: the hood light glows above
        float t = clamp(sc.y / max(front, 1.0), 0.0, 1.0);
        vec3 glow = mix(lightColor, vec3(1.0), 0.5) * lamp;
        col = airColor + glow * (1.0 - t) * (1.0 - t) * 0.9;

        // Condensation beads on the inside of the glass
        vec2 g = sc / vec2(9.0, 8.0);
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;
        float rnd = hash(id);
        vec2 jit = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
        float dist = length(f - jit * 0.45);
        float rad = 0.12 + 0.22 * hash(id + 1.9);
        float bead = (1.0 - smoothstep(rad - 0.06, rad, dist)) * step(0.35, rnd);
        float rim = smoothstep(rad - 0.12, rad - 0.02, dist) * bead;
        float hi = (1.0 - smoothstep(0.0, rad * 0.45, length(f - jit * 0.45 - vec2(-0.05, -0.06)))) * bead;
        col = mix(col, col * 0.55, rim * 0.6);
        col += glow * hi * 0.5 + hi * 0.05;
    } else if (sc.y < back) {
        // Underside of the surface: total internal reflection of the tank
        float f = (sc.y - front) / max(back - front, 1.0);
        float ry = back + (back - sc.y) * 2.4;
        vec2 ruv = vec2(sc.x + slope * 70.0 + sin(sc.y * 0.45 + time * 2.1) * 1.6, ry) / size;
        col = Texel(scene, clamp(ruv, vec2(0.001), vec2(0.999))).rgb;
        col *= 0.80 + 0.15 * f;

        // Glints where the waves catch the lamp
        float wob = sin(sc.x * 0.013 + time * 0.4) * 3.0 + sin(sc.x * 0.031 - time * 0.7) * 2.0;
        float glint = pow(max(0.0, sin(sc.x * 0.071 + slope * 50.0 + wob + time * 1.3)
                                 * sin(sc.y * 0.29 + wob * 0.7 - time * 0.8)), 22.0);
        glint *= smoothstep(0.35, 0.9, hash(floor(vec2(sc.x / 23.0, sc.y / 7.0))));
        col += lightColor * lightI * glint * 0.7;
        col = mix(col, lightColor * lightI, 0.05);
    } else {
        col = sampleScene(scene, uv);
    }

    // The waterline: a thin bright meniscus against the front glass
    float m = exp(-pow((sc.y - front) / 1.2, 2.0));
    col += (lightColor * lightI * 0.55 + 0.12) * m;
    // The far edge of the surface catches a little light too
    float be = exp(-pow((sc.y - back) / 1.8, 2.0));
    col += lightColor * lightI * be * 0.12;

    // Grain plus dither before 8-bit quantization (prevents banding)
    float n = hash(sc + fract(time * 7.13) * 100.0) - 0.5;
    col += n * grain + (hash(sc * 1.37 + 11.0) - 0.5) / 255.0;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}
