
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 mvm;
    float pz, dMin, dMax, dens, jit, t;
    float aL, aM, aH, fb;
    int vM; float asp;
    float fx, fy, cx, cy, zm;
    float stT, lS, mS, hS;
    float p1, p2, p3; 
    float4 cB;
};

struct VOut {
    float4 pos [[position]];
    float4 col;
    float p_sz [[point_size]];
};

vertex VOut v_m(device const float *depth [[buffer(0)]], constant Uniforms &u [[buffer(2)]], uint vid [[vertex_id]]) {
    uint x_pix = vid % 512; uint y_pix = vid / 512; float z = depth[vid]; VOut o;
    if (z <= u.dMin || z >= u.dMax || z <= 1.0) { o.pos = float4(0,0,0,1); o.col = float4(0,0,0,0); return o; }
    float z_n = (z - u.dMin) / (max(0.1, u.dMax - u.dMin));
    float b = u.aL * u.lS; float m = u.aM * u.mS; float h = u.aH * u.hS;
    float x_m = (float(x_pix) - u.cx) * z / u.fx; float y_m = (u.cy - float(y_pix)) * z / u.fy;
    float ang = float(vid) * 2.39996 + u.t * (0.2 + m * 2.0);
    float spr = u.jit * (1.0 + b * 15.0);
    float3 off = float3(cos(ang) * spr, sin(ang) * spr, h * 0.05);
    float sc = 0.0008 * u.zm * (1.0 + b * 0.1); 
    float3 p = float3(x_m * sc / u.asp, y_m * sc, z_n) + off;
    float3 col = u.cB.rgb;
    switch(u.vM) {
        case 0: col *= (1.0 - z_n); break;
        case 1: col = float3(1.0 - z_n, z_n, b); break;
        case 2: col = float3(sin(u.t + z*0.01), cos(u.t + z*0.01), 1.0); break;
        case 3: col = float3(b, m, h); break;
        case 4: col *= abs(sin(float(vid)*0.001 + u.t)); break;
        case 5: col = float3(sin(u.t + z*0.01), cos(u.t*0.8 + z*0.01), sin(u.t*0.5)); break;
        case 6: col = (h > 0.5) ? float3(1.0) : col * 0.3; break;
        case 7: col = float3(z_n); break;
        case 8: col = float3(sin(float(x_pix)*0.1), cos(float(y_pix)*0.1), b); break;
    }
    if (h > u.stT) col = float3(1.0);
    o.pos = float4(p, 1.0); o.col = float4(col, 1.0); o.p_sz = u.pz * (1.0 + b * 2.0);
    return o;
}

fragment float4 f_m(VOut i [[stage_in]], float2 pt [[point_coord]]) {
    if (length(pt - 0.5) > 0.5) discard_fragment();
    return i.col;
}
