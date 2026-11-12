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
    vec2 p = (uv - 0.5) * vec2(res.x / res.y, 1.0) * 2.1;
    float t = u_time * 0.18;

    // Two-stage trigonometric domain warping for silky liquid currents
    vec2 q = vec2(
        sin(p.x * 1.1 + t) + cos(p.y * 1.3 - t * 0.8),
        cos(p.x * 1.2 - t * 0.7) + sin(p.y * 1.1 + t * 0.9)
    );
    vec2 r = vec2(
        sin(p.y * 1.4 + q.x * 1.3 + t * 0.6),
        cos(p.x * 1.3 + q.y * 1.4 - t * 0.5)
    );

    float f1 = 0.5 + 0.5 * sin(length(q) * 1.4 + r.x * 1.2);
    float f2 = 0.5 + 0.5 * cos(length(r) * 1.6 - q.y * 1.1 + t * 0.4);
    float ridge = pow(clamp(1.0 - abs(f1 - f2) * 1.8, 0.0, 1.0), 2.2);

    vec3 col = u_bg.rgb;
    col = mix(col, mix(u_bg.rgb, u_c2.rgb, 0.48), f1 * 0.55 * u_intensity);
    col = mix(col, mix(u_bg.rgb, u_c3.rgb, 0.52), f2 * 0.45 * u_intensity);
    col += u_c1.rgb * ridge * 0.38 * u_intensity;

    float vig = 1.0 - dot(uv - 0.5, uv - 0.5) * 0.48;
    col *= clamp(vig, 0.62, 1.0);

    float ditherN = hash12(uv * res) - 0.5;
    col = clamp(col + ditherN * (1.5 / 255.0), 0.0, 1.0);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
