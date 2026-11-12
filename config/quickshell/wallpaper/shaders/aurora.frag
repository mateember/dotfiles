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

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.80, -0.60, 0.60, 0.80);
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = rot * p * 2.05 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - 0.5) * vec2(res.x / res.y, 1.0);
    float t = u_time * 0.14;

    // Deep atmospheric sky base
    vec3 col = mix(u_bg.rgb * 0.72, u_bg.rgb * 1.15, clamp(1.0 - uv.y, 0.0, 1.0));

    // Subtle distant star glints in upper sky
    vec2 sg = floor(p * 85.0);
    float sh = hash12(sg);
    if (sh > 0.992) {
        vec2 sc = fract(p * 85.0) - 0.5;
        float sd = length(sc);
        float tw = 0.55 + 0.45 * sin(u_time * 1.6 + sh * 120.0);
        col += mix(u_c2.rgb, vec3(1.0), 0.7) * smoothstep(0.28, 0.0, sd) * tw * 0.35 * smoothstep(0.85, 0.15, uv.y);
    }

    // Flowing aurora ribbons
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float phase = t * (0.85 + fi * 0.23) + fi * 2.1;
        float wave = sin(p.x * (1.7 + fi * 0.55) + phase) * 0.16
                   + cos(p.x * (3.1 - fi * 0.4) - phase * 0.7) * 0.07;
        float n = fbm(vec2(p.x * 1.6 + phase * 0.35, p.y * 1.1 - t * 0.4 + fi * 3.0));
        float yCenter = -0.14 + fi * 0.13 + wave + (n - 0.5) * 0.22;
        float dist = p.y - yCenter;

        // Asymmetric curtain: crisp bottom edge, soft upward shimmer
        float curtain = smoothstep(-0.18, 0.02, dist) * exp(-max(dist, 0.0) * (5.2 - fi * 0.6));
        float rays = 0.65 + 0.35 * sin(p.x * 11.0 + n * 7.0 + phase * 1.5);
        vec3 ribCol = (i == 0) ? u_c1.rgb : (i == 1) ? u_c2.rgb : u_c3.rgb;
        col += ribCol * curtain * rays * (0.42 - fi * 0.06) * u_intensity;
    }

    // Soft horizon glow and vignette
    float vig = 1.0 - dot(uv - 0.5, uv - 0.5) * 0.55;
    col *= clamp(vig, 0.55, 1.0);

    float ditherN = hash12(uv * res) - 0.5;
    col = clamp(col + ditherN * (1.5 / 255.0), 0.0, 1.0);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
