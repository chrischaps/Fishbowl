// Lighting for everything that lives in the water: ambient light, caustic
// dapple from above, then distance haze toward the water color.
extern vec3 ambient;
extern vec3 fog;
extern float haze;
extern Image caustics;
extern float causticGain;
extern vec3 causticColor;
extern vec2 size;

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    vec4 c = Texel(tex, tc) * vcolor;
    vec3 lit = c.rgb * ambient;
    vec3 cs = Texel(caustics, sc / size).rgb;
    lit += c.rgb * causticColor * cs * causticGain;
    lit = mix(lit, fog, haze);
    return vec4(lit, c.a);
}
