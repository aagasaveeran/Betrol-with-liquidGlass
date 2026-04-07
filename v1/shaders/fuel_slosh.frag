#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uFillLevel;
uniform float uTilt;
uniform float uTime;
uniform float uSlosh;      // Velocity magnitude (How hard it's moving)
uniform float uGForce;     // Gravity magnitude (For upside-down freefall)

out vec4 fragColor;

// Generate organic noise
float hash(float n) { return fract(sin(n) * 43758.5453123); }

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec2 p = uv - vec2(0.5);

    // Apply the physically accurate tilt
    float cosT = cos(uTilt);
    float sinT = sin(uTilt);
    vec2 rotP = vec2(p.x * cosT - p.y * sinT, p.x * sinT + p.y * cosT);
    rotP += vec2(0.5);

    // --- PHYSICS DISTORTIONS ---
    float distFromCenter = (rotP.x - 0.5) * 2.0; // Range -1 to 1
    
    // 1. Splashing Waves (Chaos increases with uSlosh)
    float waveTime = uTime * 4.0;
    float baseWave = sin(rotP.x * 6.0 + waveTime) * 0.015;
    float splashWave = sin(rotP.x * 15.0 - waveTime * 1.5) * (uSlosh * 0.015);
    
    // 2. Wall Creep (Liquid pushes up the glass walls during hard turns)
    float wallCreep = (distFromCenter * distFromCenter) * uSlosh * 0.015;
    
    // 3. Freefall Clump (When flipped upside down, liquid balls up in the center temporarily)
    float freefallClump = smoothstep(9.8, 0.0, uGForce) * cos(distFromCenter * 3.14) * 0.15;
    
    // 4. Tremble (Engine vibration / high-frequency jitter)
    float tremble = (hash(uTime + p.x) - 0.5) * clamp(uSlosh * 0.005, 0.0, 0.02);

    float level = 1.0 - uFillLevel;
    float surfaceDistortion = baseWave + splashWave + wallCreep + tremble - freefallClump;

    // --- RENDERING ---
    if (rotP.y > level + surfaceDistortion) {
        // Deep Liquid Gradient
        vec3 colorTop = vec3(1.0, 0.75, 0.0);
        vec3 colorBot = vec3(0.2, 0.05, 0.0);
        float depth = clamp((rotP.y - (level + surfaceDistortion)) * 2.0, 0.0, 1.0);
        vec3 finalColor = mix(colorTop, colorBot, depth);
        
        // Surface Foam Line
        float foam = smoothstep(0.02 + uSlosh*0.01, 0.0, abs(rotP.y - (level + surfaceDistortion)));
        finalColor += foam * vec3(1.0, 0.9, 0.5) * clamp(uSlosh * 0.3, 0.0, 1.0);
        
        // Sub-surface Bubbles
        float bubbleGrid = sin(rotP.x * 50.0 + uTime * 2.0) * sin(rotP.y * 50.0 - uTime * 3.0);
        float bubbles = smoothstep(0.85, 1.0, bubbleGrid) * clamp(uSlosh - 1.5, 0.0, 1.0) * 0.4;
        finalColor += bubbles;

        fragColor = vec4(finalColor, 0.95);
    } else {
        // Flying Splashes/Droplets above the surface during violent movement
        float dropletField = sin(rotP.x * 60.0 + uTime * 6.0) * sin(rotP.y * 60.0 + uTime * 5.0);
        float distToSurface = (level + surfaceDistortion) - rotP.y;
        
        if (uSlosh > 2.0 && distToSurface > 0.0 && distToSurface < uSlosh * 0.05) {
            if (dropletField > 0.97) {
                fragColor = vec4(1.0, 0.8, 0.0, 0.8);
                return;
            }
        }
        fragColor = vec4(0.0);
    }
}