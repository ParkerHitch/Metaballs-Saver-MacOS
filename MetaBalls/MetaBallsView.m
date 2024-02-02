//
//  MetaBallsView.m
//  MetaBalls
//
//  Created by Parker Hitchcock on 5/10/23.
//

#import "MetaBallsView.h"
#import <OSLog/OSLog.h>

typedef struct {
    vector_float4 position;
    vector_float4 color;
} VertexInfo;
typedef struct {
    vector_float2 size;
    float slope;
} Dimensions;

@implementation MetaBallsView {
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _library;
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    id<MTLBuffer> _screenSizeBuffer;
    id<MTLRenderPipelineState> _renderPipelineState;
    NSUInteger _indexCount;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (!self)
        return NULL;
    if (![self initMetal])
        return NULL;
    self.animationTimeInterval = 1.0/60.0;
    return self;
}

- (void)startAnimation
{
    if (![_mtkview isDescendantOf:self]) {
        [self addSubview:_mtkview];
    }
    [super startAnimation];
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (void)drawRect:(NSRect)rect
{
    [super drawRect:rect];
}

- (void)animateOneFrame
{
    [self drawInMTKView:_mtkview];
    return;
}

// MAIN LOOP:

- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    MTLRenderPassDescriptor* descriptor = view.currentRenderPassDescriptor;
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    
    
    //     encoding commands
    [commandEncoder setRenderPipelineState:_renderPipelineState];
    
    [commandEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
    
    [commandEncoder setFragmentBuffer:_screenSizeBuffer offset:0 atIndex:0];
    
    [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:_indexCount indexType:MTLIndexTypeUInt16 indexBuffer:_indexBuffer indexBufferOffset:0];
    [commandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];

    //  committing the drawing
    [commandEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)setFrameSize:(NSSize)newSize {
    [self mtkView:_mtkview drawableSizeWillChange:newSize];
    [super setFrameSize:newSize];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    [_mtkview setFrameSize:size];
}


// METAL SETUP:

// Helpers:
_Nullable id<MTLLibrary> MSSNewDefaultBundleLibrary(const id<MTLDevice> device)
{
    NSBundle *bundle = [NSBundle bundleWithIdentifier:@"phitch.MetaBalls"];
    NSError *error = NULL;
    id<MTLLibrary> library = [device newDefaultLibraryWithBundle:bundle error:&error];
    if (!library) {
        os_log_error(OS_LOG_DEFAULT, "Failed to create library %@", error);
        return NULL;
    }
    return library;
}
_Nullable id<MTLRenderPipelineState>
MSSMakeRenderPipelineState(_Nonnull id<MTLDevice> device,
                           MTLRenderPipelineDescriptor * _Nonnull descriptor)
{
    NSError *error = NULL;
    id<MTLRenderPipelineState> renderState =
        [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (!renderState) {
        os_log_error(OS_LOG_DEFAULT, "Failed to create render pipeline state, %@", error);
        return NULL;
    }
    return renderState;
}

// Real init:
- (bool)initMetal {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        os_log_error(OS_LOG_DEFAULT, "Metal is not supported.");
        return false;
    }
    
    _mtkview = [[MTKView alloc] initWithFrame:self.frame device:device];
    _mtkview.delegate = self;
    _mtkview.clearColor = MTLClearColorMake(0, 0, 0, 1);
    
    //     creating vertex buffer
    VertexInfo vertexInfo[] = {
        {{-1, -1, 0, 1}, {1, 0, 0, 1}},
        {{-1, 1, 0, 1} , {0, 1, 0, 1}},
        {{1, 1, 0, 1}, {0, 0, 1, 1}},
        {{1, -1, 0, 1}, {0, 0, 1, 1}}
    };
    _vertexBuffer = [device newBufferWithBytes:vertexInfo length:sizeof(vertexInfo) options:MTLResourceOptionCPUCacheModeDefault];
    
    Dimensions screenSize;
    screenSize.size.x = self.frame.size.width;
    screenSize.size.y = self.frame.size.height;
    screenSize.slope = screenSize.size.y/screenSize.size.x;
    _screenSizeBuffer = [device newBufferWithBytes:&screenSize length:sizeof(screenSize) options:MTLResourceOptionCPUCacheModeDefault];
    
    // creating index buffer
//    uint16_t indexInfo[] = {2, 1, 1, 0, 0, 2};
    uint16_t indexInfo[] = {2, 1, 0,3,2,0};
    _indexCount = sizeof(indexInfo) / sizeof(uint16_t);
    _indexBuffer = [device newBufferWithBytes:indexInfo length:sizeof(indexInfo) options:MTLResourceOptionCPUCacheModeDefault];
    
    // creating command queue and shader functions
    _commandQueue = [device newCommandQueue];
    _library = MSSNewDefaultBundleLibrary(device);
    id<MTLFunction> vertexShader = [_library newFunctionWithName:@"vertex_shader"];
    id<MTLFunction> fragmentShader = [_library newFunctionWithName:@"fragment_shader"];
    
    // creating render pipeline
    MTLRenderPipelineDescriptor *renderPipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDesc.label = @"Simple Pipeline";
    renderPipelineDesc.vertexFunction = vertexShader;
    renderPipelineDesc.fragmentFunction = fragmentShader;
    renderPipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    if (!(_renderPipelineState = MSSMakeRenderPipelineState(device, renderPipelineDesc)))
        return false;
    
    return true;
}

- (BOOL)hasConfigureSheet
{
    return NO;
}

- (NSWindow*)configureSheet
{
    return nil;
}

@end
