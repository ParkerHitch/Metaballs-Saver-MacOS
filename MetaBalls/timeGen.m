//
//  timeGen.m
//  MetaBalls
//
//  Created by Parker Hitchcock on 2/17/24.
//

#import <Foundation/Foundation.h>
#import "MetaBallsView.h"
#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>
#import "timeGen.h"
#import "MetaBallConstants.h"

#include <ft2build.h>
#include FT_FREETYPE_H

#define FONTNAME "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"

@implementation timeSDFGenerator {
    FT_Library library;
    FT_Face face;
    FT_GlyphSlot glyph;
    char timeStr[6];
    
    int baselineY;
    
}

+ (id) init: (int)winHeight {
    
    int texHeight = winHeight*MTABLS_DISTTEX_RENDER_SCALE;
    
    timeSDFGenerator* testOut = [timeSDFGenerator alloc];
    int error = 0;
    error += FT_Init_FreeType(&testOut->library);
    error += FT_New_Face(testOut->library, FONTNAME, 0, &testOut->face);
    error += FT_Set_Pixel_Sizes(testOut->face, texHeight/2, 0);
    
    testOut->glyph = testOut->face->glyph;
    
    int colonInd = FT_Get_Char_Index(testOut->face, ':');
    
    error += FT_Load_Glyph(testOut->face, colonInd, 0);
    FT_Glyph_Metrics colonMetrics = testOut->glyph->metrics;
    
    // + & - inverted because +y is down
    testOut->baselineY = (texHeight/2) - ((colonMetrics.height>>6)/2) + (colonMetrics.horiBearingY>>6);

    
    if(error)
        return nil;
    return testOut;
}

- (void) writeSDF: (id<MTLTexture>)timeTex :(int)hour :(int)minute
{
    
    uint8* stupidBuff = calloc(timeTex.width*timeTex.height, 1);

    MTLRegion charRegion = {
        {0,0,0},
        {timeTex.width,timeTex.height, 1}
    };
    [timeTex replaceRegion:charRegion
               mipmapLevel: 0
                 withBytes: stupidBuff
               bytesPerRow: timeTex.width];

    free(stupidBuff);
    
    sprintf(timeStr, "%d:%02d", hour, minute);
    float totalAdvance = 0;
    for(int i=0; i<strlen(timeStr); i++){
        FT_Load_Glyph(face, FT_Get_Char_Index(face, timeStr[i]) , 0);
        FT_Glyph_Metrics metrics = glyph->metrics;
        totalAdvance += (metrics.horiAdvance / 64.0); // convert from 26.6 to float
    }

    int penX = (timeTex.width/2.0) - (totalAdvance/2.0);

    for(int i=0; i<strlen(timeStr); i++){

        FT_Load_Glyph(face, FT_Get_Char_Index(face, timeStr[i]), 0);
        FT_Render_Glyph(face->glyph, FT_RENDER_MODE_SDF);



        MTLRegion charRegion = {
            {penX + glyph->bitmap_left, baselineY - glyph->bitmap_top, 0},
            {glyph->bitmap.width, glyph->bitmap.rows, 1}
        };

        [timeTex replaceRegion:charRegion
                   mipmapLevel: 0
                     withBytes: glyph->bitmap.buffer
                   bytesPerRow: glyph->bitmap.pitch];

        penX += glyph->metrics.horiAdvance/64;

    }
    
}

@end
