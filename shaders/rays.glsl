// Volumetric light shafts. They share the surface height field, so ripples
// above make the rays below flicker. Mirrored in Lua by Water.rayLight().
extern vec3 lightColor;
extern float intensity;
extern float time;
extern float angle;      // screen dx per dy
extern float topY;       // where rays enter (surface at back glass)
extern float floorY;     // where rays fade out
extern float width;
extern Image surfaceTex; // g = curvature (0.5 = flat)

float shafts(float xs, float t) {
    float s = 0.5 + 0.5 * (0.5 * sin(xs * 0.011 + t * 0.13)
                         + 0.3 * sin(xs * 0.023 - t * 0.21 + 1.7)
                         + 0.2 * sin(xs * 0.047 + t * 0.37 + 4.1));
    return pow(s, 5.0);
}

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    float y = sc.y - topY;
    if (y < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    float xs = sc.x - y * angle;
    // Shafts spread slightly as they descend
    xs = mix(xs, width * 0.5 + (xs - width * 0.5) * 0.86, clamp(y / 600.0, 0.0, 1.0));

    float s = shafts(xs, time);
    float shimmer = 0.75 + 0.25 * sin(xs * 0.11 + time * 1.9) * sin(xs * 0.071 - time * 1.3);
    float curv = Texel(surfaceTex, vec2(clamp(xs / width, 0.0, 1.0), 0.5)).g - 0.5;
    float lens = clamp(1.0 + curv * 6.0, 0.3, 2.5);

    float span = floorY - topY;
    float fade = exp(-y / 420.0) * smoothstep(0.0, 50.0, y) * (1.0 - smoothstep(span - 90.0, span + 30.0, y));

    float a = s * shimmer * lens * fade * intensity;
    return vec4(lightColor * a, 1.0);
}
