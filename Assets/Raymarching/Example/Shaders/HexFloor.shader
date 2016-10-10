Shader "Raymarching/HexFloor"
{

Properties
{
    [Header(PBS)]
    _Color("Color", Color) = (1.0, 1.0, 1.0, 1.0)
    _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
    _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
    _Glossiness2("2Smoothness", Range(0.0, 1.0)) = 0.5

    [Header(Raymarching Settings)]
    _Loop("Loop", Range(1, 100)) = 30
    _MinDistance("Minimum Distance", Range(0.001, 0.1)) = 0.01
    _ShadowLoop("Shadow Loop", Range(1, 100)) = 10
    _ShadowMinDistance("Shadow Minimum Distance", Range(0.001, 0.1)) = 0.01

// @block Properties
[Header(Additional Properties)]
_TopColor("TopColor", Color) = (1, 1, 1, 0)
// @endblock
}

SubShader
{

Tags
{
    "RenderType" = "Opaque"
    "DisableBatching" = "True"
}

CGINCLUDE





#define DISTANCE_FUNCTION DistanceFunction
#define POST_EFFECT PostEffect
#define PostEffectOutput SurfaceOutputStandard

#include "Assets/Raymarching/Shaders/Include/Common.cginc"

// @block DistanceFunction
inline float DistanceFunction(float3 pos)
{
    // combine even hex tiles and odd hex tiles

    float radius = 0.3;
    float space = 0.1;
    float wave = 0.1;
    float height = abs(_Scale.y) * 0.5 - wave;
    float3 scale = abs(_Scale * 0.5);

    float pitch = radius * 2 + space;
    float3 offset = float3(pitch * 0.5, 0.0, pitch * 0.866);
    float3 loop = float3(offset.x * 2, 1.0, offset.z * 2);
	
    float3 p1 = pos;
    float3 p2 = pos + offset;

    // calculate indices
    float2 pi1 = floor(p1 / loop).xz;
    float2 pi2 = floor(p2 / loop).xz;
    pi1.y = pi1.y * 2 + 1;
    pi2.y = pi2.y * 2;

    p1 = Repeat(p1, loop);
    p2 = Repeat(p2, loop);

    // draw hexagonal prisms with random heights
    float dy1 = wave * sin(10 * Rand(pi1) + 5 * PI * _Time.x);
    float dy2 = wave * sin(10 * Rand(pi2) + 5 * PI * _Time.x);
    float d1 = HexagonalPrismY(float3(p1.x, pos.y + dy1, p1.z), float2(radius, height));
    float d2 = HexagonalPrismY(float3(p2.x, pos.y + dy2, p2.z), float2(radius, height));

    // maximum indices
    loop.z *= 0.5;
    float2 mpi1 = floor((scale.xz + float2(space * 0.5,    radius)) / loop.xz);
    float2 mpi2 = floor((scale.xz + float2(radius + space, radius)) / loop.xz);

    // remove partial hexagonal prisms
    // if (pi1.x >= mpi1.x || pi1.x <  -mpi1.x) d1 = max(d1, space);
    // if (pi1.y >= mpi1.y || pi1.y <= -mpi1.y) d1 = max(d1, space);
    float o1 = any(
        step(mpi1.x, pi1.x) +
        step(pi1.x + 1, -mpi1.x) +
        step(mpi1.y, abs(pi1.y)));
    d1 = o1 * max(d1, 0.1) + (1 - o1) * d1;

    //  if (!all(max(mpi2 - abs(pi2), 0.0))) d2 = max(d2, space);
    float o2 = any(step(mpi2, abs(pi2)));
    d2 = o2 * max(d2, 0.1) + (1 - o2) * d2;

    // combine
    return min(d1, d2);
}
// @endblock

// @block PostEffect
float4 _TopColor;

inline void PostEffect(RaymarchInfo ray, inout PostEffectOutput o)
{
    float3 localPos = ToLocal(ray.endPos);
    o.Emission += smoothstep(0.48, 0.50, localPos.y) * _TopColor;
}
// @endblock

#include "Assets/Raymarching/Shaders/Include/Raymarching.cginc"

ENDCG

Pass
{
    Tags { "LightMode" = "Deferred" }

    Stencil
    {
        Comp Always
        Pass Replace
        Ref 128
    }

    CGPROGRAM
    #include "Assets/Raymarching/Shaders/Include/VertFragStandardObject.cginc"
    #pragma target 3.0
    #pragma vertex Vert
    #pragma fragment Frag
    #pragma multi_compile_prepassfinal
    #pragma exclude_renderers nomrt
    ENDCG
}

Pass
{
    Tags { "LightMode" = "ShadowCaster" }

    CGPROGRAM
    #include "Assets/Raymarching/Shaders/Include/VertFragShadowObject.cginc"
    #pragma target 3.0
    #pragma vertex Vert
    #pragma fragment Frag
    #pragma multi_compile_shadowcaster
    #pragma fragmentoption ARB_precision_hint_fastest
    ENDCG
}

}

Fallback "Raymarching/Fallbacks/StandardSurfaceShader"

CustomEditor "Raymarching.MaterialEditor"

}