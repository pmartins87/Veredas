shader_type canvas_item;

uniform vec4 paper_light : source_color = vec4(0.93, 0.87, 0.72, 1.0);
uniform vec4 paper_dark : source_color = vec4(0.58, 0.46, 0.29, 1.0);
uniform vec4 domain_wash : source_color = vec4(0.32, 0.38, 0.20, 1.0);
uniform float domain_strength : hint_range(0.0, 0.22) = 0.07;
uniform float age_strength : hint_range(0.0, 1.0) = 0.32;
uniform float fiber_strength : hint_range(0.0, 0.25) = 0.07;
uniform float edge_strength : hint_range(0.0, 0.8) = 0.22;
uniform float stain_strength : hint_range(0.0, 0.25) = 0.045;
uniform float seed = 17.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345 + seed);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += value_noise(p) * a;
        p = p * 2.03 + vec2(17.2, 9.1);
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV;
    float coarse = fbm(uv * 7.0 + seed);
    float fine = fbm(uv * vec2(72.0, 18.0) + seed * 0.13);
    float vertical_fiber = abs(sin((uv.y + fine * 0.018) * 1300.0));
    vertical_fiber = smoothstep(0.89, 1.0, vertical_fiber);
    float horizontal_fiber = abs(sin((uv.x + fine * 0.010) * 850.0));
    horizontal_fiber = smoothstep(0.94, 1.0, horizontal_fiber);

    vec2 edge_d = min(uv, vec2(1.0) - uv);
    float edge = 1.0 - smoothstep(0.0, 0.09, min(edge_d.x, edge_d.y));
    float corner = length((uv - vec2(0.5)) * vec2(1.0, 0.72));
    float vignette = smoothstep(0.42, 0.72, corner);

    float stains = smoothstep(0.61, 0.79, fbm(uv * 4.4 + vec2(seed, -seed)));
    float grain = (coarse - 0.5) * age_strength;

    vec3 paper = mix(paper_light.rgb, paper_dark.rgb, clamp(0.16 + grain + edge * edge_strength + vignette * 0.10, 0.0, 0.72));
    paper = mix(paper, domain_wash.rgb, domain_strength * (0.55 + coarse * 0.45));
    paper -= vec3((vertical_fiber + horizontal_fiber) * fiber_strength);
    paper -= vec3(stains * stain_strength);

    vec4 src = texture(TEXTURE, uv);
    COLOR = vec4(paper, 1.0) * COLOR;
    if (src.a > 0.001) {
        COLOR.rgb = mix(COLOR.rgb, src.rgb, src.a);
    }
}