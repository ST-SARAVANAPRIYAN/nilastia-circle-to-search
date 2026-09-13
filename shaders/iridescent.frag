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
    float triggerWave;
    vec2 resolution;
} ubuf;

// Authentic Google Lens chromatic spectrum interpolation (branchless & C-infinity smooth)
vec3 googleLensPalette(float t) {
    float f = fract(t);

    // Iconic Google Material hues
    vec3 cBlue   = vec3(0.259, 0.522, 0.957); // #4285F4 Blue
    vec3 cRed    = vec3(0.918, 0.263, 0.208); // #EA4335 Red
    vec3 cYellow = vec3(0.984, 0.737, 0.020); // #FBBC05 Yellow
    vec3 cGreen  = vec3(0.204, 0.659, 0.325); // #34A853 Green

    // Periodic bell weights centered at 0.0, 0.25, 0.50, 0.75
    float w0 = 0.5 + 0.5 * cos(6.2831853 * (f - 0.00));
    float w1 = 0.5 + 0.5 * cos(6.2831853 * (f - 0.25));
    float w2 = 0.5 + 0.5 * cos(6.2831853 * (f - 0.50));
    float w3 = 0.5 + 0.5 * cos(6.2831853 * (f - 0.75));

    // Sharpen bell curves slightly for rich color saturation
    w0 = w0 * w0;
    w1 = w1 * w1;
    w2 = w2 * w2;
    w3 = w3 * w3;

    float sum = w0 + w1 + w2 + w3;
    return (cBlue * w0 + cRed * w1 + cYellow * w2 + cGreen * w3) / max(sum, 0.001);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 pixelCoord = uv * ubuf.resolution;

    // 1. Distance to screen perimeter edges
    float distLeft   = pixelCoord.x;
    float distRight  = ubuf.resolution.x - pixelCoord.x;
    float distTop    = pixelCoord.y;
    float distBottom = ubuf.resolution.y - pixelCoord.y;
    float d = min(min(distLeft, distRight), min(distTop, distBottom));

    // Continuous perimeter walk for circulating iridescent gleam
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

    // Circulating iridescent border hue
    vec3 borderColor = googleLensPalette(normPos * 1.5 - ubuf.time * 0.15);

    // Traveling specular gleams / flares along the perimeter
    float gleam1 = pow(max(0.0, sin(6.2831853 * (normPos * 2.0 - ubuf.time * 0.35))), 14.0) * 0.45;
    float gleam2 = pow(max(0.0, cos(6.2831853 * (normPos * 3.0 + ubuf.time * 0.20))), 16.0) * 0.25;
    vec3 borderGleam = borderColor + vec3(gleam1 + gleam2);

    // Multi-layer glowing border profile:
    // Core sharp perimeter rim
    float core = 1.0 - smoothstep(0.0, ubuf.borderWidth, d);
    // Atmospheric exponential inner radiance
    float innerGlow = exp(-d / max(ubuf.borderWidth * 1.8, 1.0));
    // Soft outer atmospheric haze
    float outerHaze = exp(-pow(d / max(ubuf.glowRadius * 0.7, 1.0), 1.35)) * 0.6;
    
    float pulse = 0.95 + 0.05 * sin(ubuf.time * 1.5);
    float borderAlpha = clamp((core * 0.95 + innerGlow * 0.6 + outerHaze * 0.3) * ubuf.intensity * pulse, 0.0, 1.0);

    // 2. Luminous Trigger Wave (sweeps upward from bottom pill on presentation)
    vec2 aspectUV = vec2((uv.x - 0.5) * (ubuf.resolution.x / max(ubuf.resolution.y, 1.0)) + 0.5, uv.y);
    float distFromTrigger = length(aspectUV - vec2(0.5, 1.02)); // origin at bottom center
    float wavePos = ubuf.triggerWave * 1.85;
    float waveDist = abs(distFromTrigger - wavePos);
    
    // Wave crest radiance with smooth envelope
    float waveFront = exp(-pow(waveDist / 0.12, 2.0)) * smoothstep(1.4, 0.3, ubuf.triggerWave);
    float waveTrail = smoothstep(wavePos, 0.0, distFromTrigger) * exp(-distFromTrigger * 1.4) * smoothstep(1.3, 0.2, ubuf.triggerWave) * 0.25;
    vec3 waveColor = googleLensPalette(distFromTrigger * 1.4 - ubuf.time * 0.25) + vec3(0.20);
    float waveAlpha = (waveFront * 0.38 + waveTrail * 0.16) * ubuf.intensity;

    // 3. Ambient Living Gradient Tint (soft chromatic fluid flowing across the screen)
    // Dynamic orbiting focal centers creating organic liquid silk undulation
    vec2 center1 = vec2(0.35 + 0.18 * sin(ubuf.time * 0.35), 0.40 + 0.16 * cos(ubuf.time * 0.28));
    vec2 center2 = vec2(0.65 - 0.16 * cos(ubuf.time * 0.31), 0.60 - 0.18 * sin(ubuf.time * 0.42));
    
    float d1 = length(uv - center1);
    float d2 = length(uv - center2);
    
    float flow1 = d1 * 0.75 - ubuf.time * 0.08;
    float flow2 = d2 * 0.85 + ubuf.time * 0.07;
    
    vec3 col1 = googleLensPalette(flow1);
    vec3 col2 = googleLensPalette(flow2 + 0.35);
    
    float fluidMix = smoothstep(-0.35, 0.35, sin(uv.x * 2.2 + uv.y * 1.6 + ubuf.time * 0.4) * 0.45 + (d1 - d2) * 0.6);
    vec3 ambientColor = mix(col1, col2, fluidMix);
    
    // Subtle, elegant ambient alpha (maintains underlying screen clarity)
    float ambientAlpha = (0.050 + 0.025 * sin(uv.x * 1.5 - uv.y * 1.5 + ubuf.time * 0.6)) * ubuf.intensity;

    // 4. Photometrically Correct Compositing (Pre-multiplied Alpha)
    // Base: Ambient moving tint
    vec3 accumRgb = ambientColor * ambientAlpha;
    float accumAlpha = ambientAlpha;

    // Additive / Alpha-blended Trigger Wave
    accumRgb += waveColor * waveAlpha;
    accumAlpha = clamp(accumAlpha + waveAlpha * (1.0 - accumAlpha), 0.0, 1.0);

    // Composite Iridescent Border over background tint
    vec3 borderPremul = borderGleam * borderAlpha;
    accumRgb = accumRgb * (1.0 - borderAlpha) + borderPremul;
    accumAlpha = clamp(accumAlpha + borderAlpha * (1.0 - accumAlpha), 0.0, 1.0);

    // Master opacity attenuation
    float finalAlpha = clamp(accumAlpha * ubuf.qt_Opacity, 0.0, 1.0);
    vec3 finalRgb = accumRgb * ubuf.qt_Opacity;

    fragColor = vec4(finalRgb, finalAlpha);
}
