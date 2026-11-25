// Adapts Studio's original ground, rock and colour-grade functions to Godot's
// native world lighting. It intentionally does not duplicate the Studio's
// private three.js lighting, viewport composite or outline pipeline.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float fluitown_lod_scale = 1.0;
uniform bool fluitown_ground_paint = true;
uniform bool fluitown_mountain = true;
uniform vec4 fluitown_moss = vec4(0.15, 0.19, 0.07, 0.7);
uniform vec4 fluitown_cap_grass = vec4(0.21, 0.26, 0.085, 0.8);
uniform vec3 uMmoratFloorSplatLush = vec3(0.22, 0.30, 0.09);
uniform vec3 uMmoratFloorSplatDry = vec3(0.35, 0.29, 0.16);
uniform vec3 uMmoratFloorTurf = vec3(0.20, 0.27, 0.08);
uniform vec4 uMmoratTerrainMaterialB = vec4(0.16, 0.0, 0.0, 0.0);
uniform vec3 uMmoratDriftA = vec3(1.0);
uniform vec3 uMmoratDriftB = vec3(1.0);
uniform vec4 uMmoratWeatherSurface = vec4(0.0);
uniform float uMmoratWeatherSnow = 0.0;
uniform vec3 uMmoratHaze = vec3(0.9, 0.925, 0.94);
uniform vec2 uMmoratTerrainWindDirection = vec2(1.0, 0.0);
uniform float uMmoratTerrainTime = 0.0;

vec2 mmoratMaterialHash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}
vec2 mmoratMaterialGradient(vec2 lattice) {
    vec2 gradient = mmoratMaterialHash22(lattice) * 2.0 - 1.0;
    return gradient * inversesqrt(max(dot(gradient, gradient), 0.0001));
}
float mmoratMaterialGradientNoise(vec2 p) {
    vec2 lattice = floor(p), local = fract(p);
    vec2 fade = local * local * local * (local * (local * 6.0 - 15.0) + 10.0);
    float nw = dot(mmoratMaterialGradient(lattice), local);
    float ne = dot(mmoratMaterialGradient(lattice + vec2(1.0, 0.0)), local - vec2(1.0, 0.0));
    float sw = dot(mmoratMaterialGradient(lattice + vec2(0.0, 1.0)), local - vec2(0.0, 1.0));
    float se = dot(mmoratMaterialGradient(lattice + vec2(1.0, 1.0)), local - vec2(1.0, 1.0));
    return clamp(0.5 + mix(mix(nw, ne, fade.x), mix(sw, se, fade.x), fade.y) * 0.82, 0.0, 1.0);
}
uint fluitownHash3(ivec3 c) {
    uint h = (uint(c.x) * 0x8da6b343u) ^ (uint(c.y) * 0xd8163841u) ^ (uint(c.z) * 0xcb1ab31fu);
    h ^= h >> 16u; h *= 0x7feb352du; h ^= h >> 15u; h *= 0x846ca68bu;
    return h ^ (h >> 16u);
}
vec3 fluitownUnpack3(uint h) {
    return vec3(uvec3(h, h >> 10u, h >> 20u) & uvec3(1023u)) * (1.0 / 1023.0);
}
// Region streaming is not part of finite levels. The baked pigment carries
// each cell theme; retain it for ground splats until biome uniforms are supplied.
varying vec3 terrain_pigment;
vec3 fluitownRegionSplat(vec3 native, int which, vec2 at) {
    return which < 4 ? terrain_pigment : native;
}

#include "res://terrain/render/studio_grade.gdshaderinc"
#include "res://terrain/render/terrain_ground_studio.gdshaderinc"
#include "res://terrain/render/terrain_rock_studio.gdshaderinc"

varying vec3 terrain_compile_position;
varying vec4 terrain_ground;
varying vec2 terrain_surface;

void vertex() {
    terrain_pigment = CUSTOM0.rgb;
    terrain_compile_position = VERTEX;
    terrain_ground = CUSTOM1;
    terrain_surface = UV;
}
void fragment() {
    vec3 pigment = terrain_pigment;
    float relief = 0.0;
    float kind = terrain_surface.x;
    if (kind < 0.5 && terrain_surface.y >= 0.0) {
        pigment = fluitownGroundMaterial(pigment, terrain_compile_position, terrain_ground, relief);
    } else if (kind >= 0.5 && kind < 3.5 && terrain_surface.y >= 0.0) {
        pigment = fluitownRockMaterial(pigment, terrain_compile_position, terrain_ground, kind, relief);
    }
    int family = terrain_surface.y < -0.0005 ? 3 : kind < 0.5 ? 0 : kind < 1.5 ? 1 : 2;
    ALBEDO = studio_grade(pigment, family) * tint.rgb;
    ROUGHNESS = 1.0;
}

