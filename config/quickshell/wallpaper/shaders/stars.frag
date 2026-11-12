#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float u_time;
    float u_intensity;
    vec2 u_resolution;
    vec4 u_bg;
    vec4 u_c1;
    vec4 u_c2;
    vec4 u_c3;
};

float hash12(vec2 co) {
    vec3 p3 = fract(vec3(co.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 co) {
    vec3 p3 = fract(vec3(co.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float starLayer(vec2 p, float scale, float density, float t, float layerIdx) {
    vec2 uv = p * scale;
    vec2 id = floor(uv);
    vec2 gv = fract(uv) - 0.5;
    float acc = 0.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offs = vec2(float(x), float(y));
            vec2 cell = id + offs;
            vec2 rnd = hash22(cell + layerIdx * 71.0);
            if (rnd.x > density) {
                vec2 pos = offs + (rnd - 0.5) * 0.72;
                float d = length(gv - pos);
                float size = mix(0.035, 0.095, fract(rnd.y * 13.7));
                float core = smoothstep(size, 0.0, d);
                float halo = exp(-d * 18.0) * 0.25;
                float twinkle = 0.65 + 0.35 * sin(t * (1.2 + rnd.y * 2.5) + rnd.x * 40.0);
                acc += (core + halo) * twinkle;
            }
        }
    }
    return acc;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - 0.5) * vec2(res.x / res.y, 1.0);
    float t = u_time;

    // Deep space background with subtle drifting nebula wash
    float neb1 = exp(-dot(p - vec2(sin(t * 0.05) * 0.25, cos(t * 0.04) * 0.15), p - vec2(sin(t * 0.05) * 0.25, cos(t * 0.04) * 0.15)) * 2.2);
    float neb2 = exp(-dot(p + vec2(cos(t * 0.04) * 0.30, sin(t * 0.03) * 0.18), p + vec2(cos(t * 0.04) * 0.30, sin(t * 0.03) * 0.18)) * 2.6);

    vec3 col = u_bg.rgb * 0.82;
    col += u_c2.rgb * neb1 * 0.22 * u_intensity;
    col += u_c3.rgb * neb2 * 0.18 * u_intensity;

    // 3 parallax star layers
    float s0 = starLayer(p + vec2(t * 0.008, -t * 0.004), 10.0, 0.84, t, 1.0);
    float s1 = starLayer(p + vec2(t * 0.015, -t * 0.007), 18.0, 0.82, t, 2.0);
    float s2 = starLayer(p + vec2(t * 0.025, -t * 0.011), 28.0, 0.86, t, 3.0);

    col += mix(vec3(0.95), u_c1.rgb, 0.35) * s0 * 0.85 * u_intensity;
    col += mix(vec3(0.92), u_c2.rgb, 0.45) * s1 * 0.58 * u_intensity;
    col += mix(vec3(0.88), u_c3.rgb, 0.50) * s2 * 0.38 * u_intensity;

    float vig = 1.0 - dot(uv - 0.5, uv - 0.5) * 0.42;
    col *= clamp(vig, 0.65, 1.0);

    float ditherN = hash12(uv * res) - 0.5;
    col = clamp(col + ditherN * (1.5 / 255.0), 0.0, 1.0);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
