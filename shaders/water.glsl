// Water volume behind everything: depth-dependent absorption plus light pooling
extern vec3 topColor;
extern vec3 deepColor;
extern vec3 lightColor;
extern float lightIntensity;
extern float time;
extern float topY;     // screen y of the surface at the back glass
extern float botY;     // screen y of the floor at the back glass
extern float sunX;

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    float d = clamp((sc.y - topY) / (botY - topY), 0.0, 1.0);

    // Red is absorbed first, then green: water darkens and cools with depth
    vec3 col;
    col.r = mix(topColor.r, deepColor.r, pow(d, 0.55));
    col.g = mix(topColor.g, deepColor.g, pow(d, 0.85));
    col.b = mix(topColor.b, deepColor.b, pow(d, 1.25));

    // Broad, slow variation so the water never reads as a flat fill
    float v = sin(sc.x * 0.0037 + time * 0.031) * sin(sc.y * 0.0051 - time * 0.023 + 1.7);
    col *= 0.955 + 0.045 * v;

    // Light pools under the lamp, strongest near the surface
    float dx = (sc.x - sunX) / 560.0;
    col += lightColor * lightIntensity * exp(-dx * dx) * exp(-d * 2.4) * 0.17;

    return vec4(col, 1.0);
}
