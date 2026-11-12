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
    float t = u_time * 0.22;

    vec3 col = u_bg.rgb;

    // 5 smooth drifting bokeh / ambient color fields
    vec2 c0 = vec2(sin(t * 0.71) * 0.45, cos(t * 0.53) * 0.28);
    vec2 c1 = vec2(cos(t * 0.61 + 1.4) * 0.52, sin(t * 0.47 + 0.8) * 0.30);
    vec2 c2 = vec2(sin(t * 0.43 + 2.8) * 0.40, sin(t * 0.67 + 2.1) * 0.26);
    vec2 c3 = vec2(cos(t * 0.51 + 4.1) * 0.56, cos(t * 0.39 + 1.1) * 0.25);
    vec2 c4 = vec2(sin(t * 0.33 + 5.2) * 0.32, cos(t * 0.58 + 3.6) * 0.32);

    float w0 = exp(-dot(p - c0, p - c0) * 3.2);
    float w1 = exp(-dot(p - c1, p - c1) * 2.8);
    float w2 = exp(-dot(p - c2, p - c2) * 3.6);
    float w3 = exp(-dot(p - c3, p - c3) * 2.5);
    float w4 = exp(-dot(p - c4, p - c4) * 4.2);

    vec3 glow = vec3(0.0);
    glow += u_c1.rgb * w0 * 0.55;
    glow += u_c2.rgb * w1 * 0.50;
    glow += u_c3.rgb * w2 * 0.48;
    glow += mix(u_c1.rgb, u_c2.rgb, 0.5) * w3 * 0.38;
    glow += mix(u_c2.rgb, u_c3.rgb, 0.5) * w4 * 0.32;

    col = mix(col, col + glow, clamp(u_intensity * 0.85, 0.0, 1.4));
    // Soft tone compression so overlapping orbs stay velvety
    col = col / (1.0 + col * 0.22);

    float vig = 1.0 - dot(uv - 0.5, uv - 0.5) * 0.45;
    col *= clamp(vig, 0.62, 1.0);

    float ditherN = hash12(uv * res) - 0.5;
    col = clamp(col + ditherN * (1.5 / 255.0), 0.0, 1.0);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
