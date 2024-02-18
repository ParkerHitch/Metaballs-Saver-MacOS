//
//  timeGen.h
//  MetaBalls
//
//  Created by Parker Hitchcock on 2/17/24.
//

#ifndef timeGen_h
#define timeGen_h

@interface timeSDFGenerator: NSObject

+ (id) init: (int)winHeight;
- (void) writeSDF: (id<MTLTexture>)timeTex :(int)hour :(int)minute;

@end

#endif /* timeGen_h */
