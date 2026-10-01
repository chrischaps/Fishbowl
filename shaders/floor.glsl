// The sand bed seen from above at a grazing angle. Caustics are computed in
// world space on the floor plane, so they recede with correct perspective.
extern vec3 ambient;
extern vec3 fog;
extern float hazeMax;
extern float time;
extern float causticAmt;
extern vec3 causticColor;
extern vec3 view;      // cx, cy, kBack
extern float floorY;
extern float floorRise;
extern float depthPx;

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
    vec4 c = Texel(tex, tc) * vcolor;

    // Recover depth from screen y on the (back-rising) floor: fixed-point solve
    float d = 0.5;
    float k = 1.0;
    for (int i = 0; i < 5; i++) {
        float y = floorY - floorRise * pow(1.0 - d, 1.3);
        k = clamp((sc.y - view.y) / (y - view.y), view.z, 1.0);
        d = (k - view.z) / (1.0 - view.z);
    }
    float wx = view.x + (sc.x - view.x) / k;

    vec2 p = vec2(wx, d * depthPx) / 240.0 + vec2(time * 0.012, -time * 0.008);
    float t = time * 0.45;
    vec3 cs = vec3(caustic(p + vec2(0.004, 0.0), t), caustic(p, t), caustic(p - vec2(0.004, 0.0), t));

    vec3 lit = c.rgb * ambient + c.rgb * cs * causticColor * causticAmt * 0.9;
    lit = mix(lit, fog, pow(1.0 - d, 1.6) * hazeMax);
    return vec4(lit, c.a);
}
