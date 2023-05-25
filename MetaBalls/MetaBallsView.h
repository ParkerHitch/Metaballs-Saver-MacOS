//
//  MetaBallsView.h
//  MetaBalls
//
//  Created by Parker Hitchcock on 5/10/23.
//

#import <ScreenSaver/ScreenSaver.h>
#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>

@interface MetaBallsView : ScreenSaverView <MTKViewDelegate> {
    MTKView *_mtkview;
};

- (bool) initMetal;

@end
