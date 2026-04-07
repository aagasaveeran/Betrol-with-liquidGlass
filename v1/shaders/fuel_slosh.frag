#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uFillLevel;
uniform float uTilt;
uniform float uTime;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    
    // Convert to centered coordinates for rotation
    vec2 p = uv - vec2(0.5);
    
    // Apply rotation based on tilt
    float cosT = cos(uTilt);
    float sinT = sin(uTilt);
    vec2 rotP = vec2(p.x * cosT - p.y * sinT, p.x * sinT + p.y * cosT);
    
    // Move back to 0.0 - 1.0 range
    rotP += vec2(0.5);
    
    // Liquid physics: Wave + Surface level
    float wave = sin(rotP.x * 8.0 + uTime * 3.0) * 0.015;
    float level = 1.0 - uFillLevel;
    
    if (rotP.y > level + wave) {
        // Fuel Gradient (Gold to Dark Amber)
        vec3 colorTop = vec3(1.0, 0.84, 0.0);
        vec3 colorBottom = vec3(0.45, 0.15, 0.02);
        vec3 finalColor = mix(colorTop, colorBottom, (rotP.y - level));
        
        fragColor = vec4(finalColor, 0.95);
    } else {
        // Transparent top part of orb
        fragColor = vec4(0.0);
    }
}