//
//  shaders.metal
//  MetaBalls
//
//  Created by Parker Hitchcock on 5/10/23.
//

#include <metal_stdlib>
#include "MetaBallConstants.h"

using namespace metal;

struct Vertex {
    float4 position [[position]];
    float2 realPos;
};

struct MarchingVertexRasterized {
    float4 position [[position]];
    float4 color;
    float2 texCoord;
};

vertex Vertex ballDistVertexShader(uint vid [[vertex_id]], constant float2 *vertices [[buffer(MTABLS_VERTEX_IN__VERTECIES)]],
                                                           constant float2& screenSize [[buffer(MTABLS_VERTEX_IN__SCREENWIDTH)]]) {
    
    Vertex out;
    
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = vertices[vid].xy;
    
    out.realPos = (out.position.xy+1) * screenSize / 2;
      
    return out;
}

fragment float4 ballDistFragmentShader(Vertex vert[[stage_in]],
                                       constant float2* ballPositions [[buffer(MTABLS_DIST_FRAGMENT_IN__B_POS)]],
                                       constant float*  ballSizes [[buffer(MTABLS_DIST_FRAGMENT_IN__B_SIZE)]]) {
    
    float sum = 0;
    float r;
    
    for(int i=0; i<MTABLS_NUM_BALLS; i++){
        r = distance(vert.realPos.xy, ballPositions[i]);
        if(r > ballSizes[i]){
            continue;
        } else {
            // Convert r to a percent
            r = r / ballSizes[i];
            // See http://www.geisswerks.com/ryan/BLOBS/blobs.html
            sum += 1 - (r * r * r * (r * (r * 6 - 15) + 10));
        }
    }
    
    return vector_float4(sum, sum, sum, 1.0);
}

vertex MarchingVertexRasterized marchingCubesVertexShader(uint vid [[vertex_id]],
                                                          constant MarchingVertex* vertices [[buffer(MTABLS_VERTEX_IN__VERTECIES)]]) {

    MarchingVertexRasterized out;
    
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = vertices[vid].position;

    out.texCoord = out.position.xy;
    
    out.color = vertices[vid].color;
    
    return out;
}


fragment float4 marchingCubesFragmentShader(MarchingVertexRasterized vert [[stage_in]],
                                            texture2d<float> texture [[texture(MTABLS_DIST_TEXTURE_IND)]],
                                            constant float2& screenSize [[buffer(MTABLS_VERTEX_IN__SCREENWIDTH)]] ){
    
    sampler simpleSampler;
    float2 baseCoord = (vert.texCoord+1) / 2;
    float2 realCoord1 = baseCoord * float2(1-MTABLS_SQUARE_SIZE, 1 - MTABLS_SQUARE_SIZE * screenSize.x / screenSize.y);
    float2 realCoord2 = realCoord1 + float2(MTABLS_SQUARE_SIZE, MTABLS_SQUARE_SIZE  * screenSize.x / screenSize.y);
    
    float c1 = texture.sample(simpleSampler, realCoord1).r;
    float c2 = texture.sample(simpleSampler, realCoord2).r;
    float c3 = texture.sample(simpleSampler, float2(realCoord1.x, realCoord2.y)).r;
    float c4 = texture.sample(simpleSampler, float2(realCoord2.x, realCoord1.y)).r;
    
    bool aboveThresh = c1 > MTABLS_BALL_THRESH || c2 > MTABLS_BALL_THRESH || c3 > MTABLS_BALL_THRESH || c4 > MTABLS_BALL_THRESH;
    bool belowThresh = c1 <=MTABLS_BALL_THRESH || c2 <=MTABLS_BALL_THRESH || c3 <=MTABLS_BALL_THRESH || c4 <=MTABLS_BALL_THRESH;
    
    
    
    float4 realColor = float4(0,0,0,1);
    
    if(aboveThresh && belowThresh){
        realColor.rgb = vert.color.rgb;
    }
    
    return realColor;
}


