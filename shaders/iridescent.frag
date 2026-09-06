#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity;
    float borderWidth;
    float glowRadius;
    vec2 resolution;
} ubuf;

// Google Lens iconic color palette interpolation
vec3 googleLensPalette(float t) {
    vec3 cBlue   = vec3(0.259, 0.522, 0.957); // #4285F4
    vec3 cRed    = vec3(0.918, 0.263, 0.208); // #EA4335
    vec3 cYellow = vec3(0.984, 0.737, 0.020); // #FBBC05
    vec3 cGreen  = vec3(0.204, 0.659, 0.325); // #34A853

    float p = fract(t) * 4.0;
    if (p < 1.0) {
        return mix(cBlue, cRed, smoothstep(0.0, 1.0, p));
    } else if (p < 2.0) {
        return mix(cRed, cYellow, smoothstep(0.0, 1.0, p - 1.0));
    } else if (p < 3.0) {
        return mix(cYellow, cGreen, smoothstep(0.0, 1.0, p - 2.0));
    } else {
        return mix(cGreen, cBlue, smoothstep(0.0, 1.0, p - 3.0));
    }
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 pixelCoord = uv * ubuf.resolution;

    float distLeft = pixelCoord.x;
    float distRight = ubuf.resolution.x - pixelCoord.x;
    float distTop = pixelCoord.y;
    float distBottom = ubuf.resolution.y - pixelCoord.y;
    float d = min(min(distLeft, distRight), min(distTop, distBottom));

    float maxGlow = ubuf.borderWidth + ubuf.glowRadius;
    if (d > maxGlow) {
        fragColor = vec4(0.0);
        return;
    }

    // Perimeter walk for smooth circulation around display edges
    float s = 0.0;
    if (distTop <= distLeft && distTop <= distRight && distTop <= distBottom) {
        s = pixelCoord.x;
    } else if (distRight <= distLeft && distRight <= distTop && distRight <= distBottom) {
        s = ubuf.resolution.x + pixelCoord.y;
    } else if (distBottom <= distLeft && distBottom <= distRight && distBottom <= distTop) {
        s = ubuf.resolution.x + ubuf.resolution.y + (ubuf.resolution.x - pixelCoord.x);
    } else {
        s = 2.0 * ubuf.resolution.x + ubuf.resolution.y + (ubuf.resolution.y - pixelCoord.y);
    }

    float perimeter = 2.0 * (ubuf.resolution.x + ubuf.resolution.y);
    float normPos = s / max(perimeter, 1.0);

    // Smooth Google Lens chromatic gradient flow
    vec3 col = googleLensPalette(normPos * 1.5 - ubuf.time * 0.2);

    // Soft travelling specular gleam
    float gleam = pow(max(0.0, sin(6.28318 * (normPos * 2.0 - ubuf.time * 0.4))), 8.0) * 0.35;
    col += vec3(gleam);

    // Refined thin border core (2px)
    float core = 1.0 - smoothstep(0.0, ubuf.borderWidth, d);
    // Exponential atmospheric bloom
    float glow = exp(-pow(max(0.0, d - ubuf.borderWidth) / max(ubuf.glowRadius * 0.35, 1.0), 1.7));

    // Subtle gentle breathing pulse
    float pulse = 0.94 + 0.06 * sin(ubuf.time * 2.0);

    float alpha = clamp((core * 0.85 + glow * 0.4) * ubuf.intensity * pulse * ubuf.qt_Opacity, 0.0, 1.0);
    vec3 rgb = col * (core * 1.15 + glow * 0.8);

    // Premultiplied alpha for Qt Quick
    fragColor = vec4(rgb * alpha, alpha);
}
