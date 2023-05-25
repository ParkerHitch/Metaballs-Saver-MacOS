//
//  shaders.metal
//  MetaBalls
//
//  Created by Parker Hitchcock on 5/10/23.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float4 color;
};

struct Dimensions {
    float2 size;
    float slope;
};


vertex Vertex vertex_shader(constant Vertex *vertices [[buffer(0)]], uint vid [[vertex_id]]) {
    // extract corresponding vertex by given index
    return vertices[vid];
}

fragment float4 fragment_shader(Vertex vert [[stage_in]], constant Dimensions &screen [[buffer(0)]]) {
    float height = (vert.position.y-(screen.slope*vert.position.x))/screen.size.y/2;
    float4 out = float4(0,0,0,0);
    out.g = height+1;
    out.b = 1-height;
    return out;
}

