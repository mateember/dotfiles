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

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - 0.5) * vec2(res.x / res.y, 1.0);
    float t = u_time * 0.32;

    vec3 col = mix(u_bg.rgb * 0.85, u_bg.rgb * 1.15, 1.0 - uv.y);

    // Layered silk wave ribbons
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float freq = 1.8 + fi * 0.35;
        float speed = t * (0.45 + fi * 0.11);
        float yLine = -0.28 + fi * 0.115
                    + sin(p.x * freq + speed + fi * 0.9) * (0.09 - fi * 0.006)
                    + cos(p.x * (freq * 0.65) - speed * 0.7 + fi) * 0.045;

        float dist = p.y - yLine;
        float fill = smoothstep(-0.015, 0.015, dist);
        float crest = exp(-abs(dist) * 34.0) * 0.55;

        vec3 bandColor = (i % 3 == 0) ? u_c1.rgb : (i % 3 == 1) ? u_c2.rgb : u_c3.rgb;
        vec3 layerBase = mix(u_bg.rgb, bandColor, (0.08 + fi * 0.025) * u_intensity);
        col = mix(col, layerBase, (1.0 - fill) * 0.68);
        col += bandColor * crest * u_intensity * 0.55;
    }

    float vig = 1.0 - dot(uv - 0.5, uv - 0.5) * 0.40;
    col *= clamp(vig, 0.68, 1.0);

    float ditherN = hash12(uv * res) - 0.5;
    col = clamp(col + ditherN * (1.5 / 255.0), 0.0, 1.0);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
