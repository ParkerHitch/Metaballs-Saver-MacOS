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

struct ColorVertex {
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
                                       constant float*  ballSizes [[buffer(MTABLS_DIST_FRAGMENT_IN__B_SIZE)]],
                                       constant float2* ballAccels [[buffer(MTABLS_DIST_FRAGMENT_IN__B_ACCEL)]]) {
    
    float sum = 0;
    float r;
    float2 rVec;
    
    for(int i=0; i<MTABLS_NUM_BALLS; i++){
        rVec = vert.realPos.xy - ballPositions[i];
        //r = distance(vert.realPos.xy, ballPositions[i]);
        rVec.x /= 1 - ballAccels[i].x;
        rVec.y /= 1 - ballAccels[i].y;
        r = distance(rVec, float2(0,0));
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

vertex Vertex marchingCubesVertexShader(uint vid [[vertex_id]],
                                        constant float2* vertices [[buffer(MTABLS_VERTEX_IN__VERTECIES)]]) {

    Vertex out;
    
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = vertices[vid];

    out.realPos = out.position.xy;
    
//    out.color = vertices[vid].color;
    
    return out;
}

float combineDistanceFields(sampler samp,
                            texture2d<float> texture [[texture(MTABLS_DIST_TEXTURE_IND)]],
                            texture2d<short> timeDistTex [[texture(MTABLS_TIMEDIST_TEXTURE_IND)]],
                            float2 coord){
    float out;
    out = texture.sample(samp, coord).r;
    float2 hack = coord;
    hack.y = 1-hack.y;
    out += ((MTABLS_BALL_THRESH / 0.5) * ((float)timeDistTex.sample(samp, hack).r)/255.0);
    return out;
}

fragment float4 marchingCubesFragmentShader(Vertex vert [[stage_in]],
                                            texture2d<float> texture [[texture(MTABLS_DIST_TEXTURE_IND)]],
                                            texture2d<short> timeDistTex [[texture(MTABLS_TIMEDIST_TEXTURE_IND)]],
                                            constant float2& screenSize [[buffer(MTABLS_VERTEX_IN__SCREENWIDTH)]] ){
    
    sampler simpleSampler(filter::linear,
                          address::clamp_to_edge,
                          min_filter::linear);
    float2 baseCoord = (vert.realPos+1) / 2;
    
    float2 pixelCoord = baseCoord * screenSize;
    
    float2 realCoord1 = pixelCoord / (screenSize+1);
    float2 realCoord2 = (pixelCoord+1) / (screenSize+1);
    
//    float c1 = texture.sample(simpleSampler, realCoord1).r;
//    float c2 = texture.sample(simpleSampler, realCoord2).r;
//    float c3 = texture.sample(simpleSampler, float2(realCoord1.x, realCoord2.y)).r;
//    float c4 = texture.sample(simpleSampler, float2(realCoord2.x, realCoord1.y)).r;
    
    float c1 = combineDistanceFields(simpleSampler, texture, timeDistTex, realCoord1);
    float c2 = combineDistanceFields(simpleSampler, texture, timeDistTex, realCoord2);
    float c3 = combineDistanceFields(simpleSampler, texture, timeDistTex, float2(realCoord1.x, realCoord2.y));
    float c4 = combineDistanceFields(simpleSampler, texture, timeDistTex, float2(realCoord2.x, realCoord1.y));
    
    bool c1In = c1 > MTABLS_BALL_THRESH;
    bool c2In = c2 > MTABLS_BALL_THRESH;
    bool c3In = c3 > MTABLS_BALL_THRESH;
    bool c4In = c4 > MTABLS_BALL_THRESH;
    
    bool aboveThresh = c1In || c2In || c3In || c4In;
    bool belowThresh = !c1In || !c2In || !c3In || !c4In;
    
//    float4 realColor = float4(0,0,0,1);
    
    float multiplier = 0;
    
    if(aboveThresh && belowThresh){
        multiplier = 1;
    }
    
//    realColor.rgb = vert.color.rgb * multiplier;
    
//    float tempTest = 0;
//    tempTest += texture.sample(simpleSampler, baseCoord).r;
//    float2 hack = baseCoord;
//    hack.y = 1-hack.y;
//    tempTest += ((MTABLS_BALL_THRESH / 0.5) * ((float)timeDistTex.sample(simpleSampler, hack).r)/255.0);
//    return vector_float4(tempTest, tempTest, tempTest, 1.0);
//
    return vector_float4(multiplier, multiplier, multiplier, 1.0);
}


vertex ColorVertex finalVertexShader(uint vid [[vertex_id]],
                                constant MarchingVertex* vertices [[buffer(MTABLS_VERTEX_IN__VERTECIES)]]) {

    ColorVertex out;
    
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = vertices[vid].position;

    out.texCoord = (out.position.xy+1) / 2;
    out.texCoord.y = 1 - out.texCoord.y;
    
    out.color = vertices[vid].color;
    
    return out;
}

constant float convMtrx[] = {
    0.002969, 0.013306, 0.021938, 0.013306, 0.002969,
    0.013306, 0.059634, 0.098320, 0.059634, 0.013306,
    0.021938, 0.098320, 1,        0.098320, 0.021938,
    0.013306, 0.059634, 0.098320, 0.059634, 0.013306,
    0.002969, 0.013306, 0.021938, 0.013306, 0.002969,
};

fragment float4 finalFragmentShader(ColorVertex vert [[stage_in]],
                                            texture2d<float> texture [[texture(MTABLS_DIST_TEXTURE_IND)]],
                                    constant float2& screenSize [[buffer(MTABLS_VERTEX_IN__SCREENWIDTH)]] ){
    
    
    
    sampler simpleSampler(coord::normalized,
                          filter::linear);

    float4 realColor = float4(0,0,0,1);

    float2 pixelCoord = vert.texCoord * screenSize;

    float sum = 0;
    for(int i=-2; i <= 2; i++){
        for(int j=-2; j <= 2; j++){
            sum += texture.sample(simpleSampler, (pixelCoord + float2(i,j)) / screenSize ).r * convMtrx[((i+2)%5) + (j+2)*5];
        }
    }
////    sum /= (5) * (5);
//

    if(sum > 1){
        sum = 1;
    }

    realColor = vert.color * sum;
//    return vert.
    
//    realColor = texture.sample(simpleSampler, pixelCoord/screenSize);
    return realColor;
}


