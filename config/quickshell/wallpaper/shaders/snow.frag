#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float u_time;
    float u_intensity;
    vec2 u_resolution;
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

vec4 snowLayer(
    vec2 p, float t, float depth, float scale, float fallSpeed,
    float windFreq, float windAmp, float minRad, float maxRad,
    float softness, float baseAlpha, float baseDensity, float seed
) {
    float spawnProb = clamp(baseDensity * (0.35 + 0.85 * u_intensity), 0.04, 0.88);
    float intScale = clamp(0.60 + 0.42 * u_intensity, 0.45, 1.15);

    // Steady downward fall (+y in Qt texture space) + gentle wind drift
    vec2 drift = vec2(
        -t * (0.012 + 0.010 * depth) - sin(t * windFreq + depth * 1.7) * windAmp,
        -t * fallSpeed
    );
    vec2 uv = (p + drift) * scale;
    vec2 id = floor(uv);
    vec2 gv = fract(uv) - 0.5;

    vec3 accCol = vec3(0.0);
    float accA = 0.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offs = vec2(float(x), float(y));
            vec2 cell = id + offs;

            float exist = hash12(cell * 1.37 + seed * 19.3);
            if (exist > spawnProb) continue;

            vec2 rnd = hash22(cell + seed * 73.1);
            float r3 = hash12(cell * 1.73 + seed * 13.1);
            float r4 = hash12(cell * 2.41 + seed * 31.7);

            float swayX = sin(t * (0.65 + r3 * 0.75) + rnd.x * 6.2831853) * (0.11 + 0.07 * depth);
            float swayY = cos(t * (0.45 + r4 * 0.45) + rnd.y * 6.2831853) * 0.035;
            vec2 center = offs + (rnd - 0.5) * 0.56 + vec2(swayX, swayY);

            float d = length(gv - center);
            float rad = mix(minRad, maxRad, r4);
            if (d >= rad) continue;

            float normD = d / rad;
            float feather = smoothstep(1.0, max(0.0, 1.0 - softness), normD);
            float profile = feather * feather;
            float coreGlint = smoothstep(0.55, 0.0, normD) * (1.0 - depth * 0.65) * 0.28;

            float alpha = clamp((profile + coreGlint) * baseAlpha * (0.68 + 0.32 * r3) * intScale, 0.0, 0.92);
            vec3 flakeCol = mix(vec3(0.91, 0.955, 1.0), vec3(1.0), 0.55 + 0.45 * (1.0 - normD));

            accCol += (1.0 - accA) * flakeCol * alpha;
            accA += (1.0 - accA) * alpha;
        }
    }

    return vec4(accCol, accA);
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - 0.5) * vec2(res.x / res.y, 1.0);
    float t = u_time;

    vec3 outCol = vec3(0.0);
    float outA = 0.0;

    // Front-to-back compositing across 5 parallax depth planes (4 = near bokeh -> 0 = distant mist)
    vec4 l4 = snowLayer(p, t, 1.00,  8.5, 0.155, 0.40, 0.055, 0.085, 0.175, 0.74, 0.36, 0.14, 5.0);
    outCol += (1.0 - outA) * l4.rgb;
    outA   += (1.0 - outA) * l4.a;

    vec4 l3 = snowLayer(p, t, 0.75, 13.5, 0.118, 0.36, 0.040, 0.068, 0.135, 0.62, 0.52, 0.20, 4.0);
    outCol += (1.0 - outA) * l3.rgb;
    outA   += (1.0 - outA) * l3.a;

    vec4 l2 = snowLayer(p, t, 0.50, 19.5, 0.088, 0.31, 0.030, 0.056, 0.110, 0.54, 0.58, 0.25, 3.0);
    outCol += (1.0 - outA) * l2.rgb;
    outA   += (1.0 - outA) * l2.a;

    vec4 l1 = snowLayer(p, t, 0.25, 28.0, 0.062, 0.27, 0.022, 0.048, 0.090, 0.48, 0.48, 0.30, 2.0);
    outCol += (1.0 - outA) * l1.rgb;
    outA   += (1.0 - outA) * l1.a;

    vec4 l0 = snowLayer(p, t, 0.00, 40.0, 0.042, 0.22, 0.015, 0.040, 0.075, 0.44, 0.38, 0.36, 1.0);
    outCol += (1.0 - outA) * l0.rgb;
    outA   += (1.0 - outA) * l0.a;

    fragColor = vec4(outCol, outA) * qt_Opacity;
}
