// Screen-space caustic light, rendered at half resolution and sampled by the
// object shader so fish, plants and rocks swim through dappled light.
extern float time;
extern vec2 size;      // full-resolution size this canvas represents
extern float scale;

#define TAU 6.28318530718

float caustic(vec2 uv, float t) {
    vec2 p = mod(uv * TAU, TAU) - 250.0;
    vec2 i = p;
    float c = 1.0;
    float inten = 0.005;
    for (int n = 0; n < 5; n++) {
        float tt = t * (1.0 - (3.5 / float(n + 1)));
        i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
        c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
    }
    c /= 5.0;
    c = 1.17 - pow(c, 1.4);
    return pow(abs(c), 8.0);
}

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    vec2 px = tc * size;
    vec2 uv = px / scale + vec2(time * 0.012, -time * 0.008);
    float t = time * 0.45;
    // Slight dispersion: each channel sampled a hair apart
    float r = caustic(uv + vec2(0.004, 0.0), t);
    float g = caustic(uv, t);
    float b = caustic(uv - vec2(0.004, 0.0), t);
    // Near the surface caustics have not yet focused
    float focus = smoothstep(0.02, 0.45, tc.y);
    return vec4(vec3(r, g, b) * focus, 1.0);
}
