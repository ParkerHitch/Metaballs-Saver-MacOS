//
//  MetaBallsView.m
//  MetaBalls
//
//  Created by Parker Hitchcock on 5/10/23.
//

#import "MetaBallsView.h"
#import <OSLog/OSLog.h>
#import "MetaBallConstants.h"

typedef struct {
    vector_float4 position;
    vector_float4 color;
} VertexInfo;

float magnitude(vector_float2 vec){
    return sqrtf(vec.x*vec.x + vec.y*vec.y);
}

@implementation MetaBallsView {
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _library;
    
    id<MTLTexture> _distTexture;
    MTLRenderPassDescriptor* _renderToDistTexRPassDescriptor;
    id<MTLRenderPipelineState> _renderToDistTexRPipeline;
    
    id<MTLTexture> _rawBallTexture;
    MTLRenderPassDescriptor* _rawBallTexRPassDescriptor;
    id<MTLRenderPipelineState> _rawBallTexRPipeline;
    
    id<MTLRenderPipelineState> _drawFinalRPipeline;
    
    float _aspectRatio;
    vector_float2 _winSize;
    vector_float2 _renderSize;
    
    vector_float2 bPositions[MTABLS_NUM_BALLS];
    float bSizes[MTABLS_NUM_BALLS];
    vector_float2 bVels[MTABLS_NUM_BALLS];
    float bVelIdeal[MTABLS_NUM_BALLS];
    vector_float2 bAccel[MTABLS_NUM_BALLS];
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    
    _mtkview.sampleCount = 1;
    
    if (!self)
        return NULL;
    if (![self initMetal])
        return NULL;
    self.animationTimeInterval = 1.0/60.0;
    
    _aspectRatio = frame.size.width / frame.size.height;
    _winSize.x = frame.size.width;
    _winSize.y = frame.size.height;
    _renderSize = _winSize*MTABLS_RENDER_SCALE;
    
    srand(time(NULL));
    for(int i=0; i < MTABLS_NUM_BALLS; i++){
        float sz = (1.5 - ((float)rand() / RAND_MAX));
        bSizes[i] = _winSize.x * MTABLS_BALL_SIZE * sz;
        bPositions[i].x = _winSize.x * ((float)rand() / RAND_MAX);
        bPositions[i].y = _winSize.y * ((float)rand() / RAND_MAX);
        float theta = 2 * M_PI * ((float)rand() / RAND_MAX);
        float velMag = _winSize.x * MTABLS_BALL_SPEED * (2 - sz);
        bVelIdeal[i] = velMag;
        bVels[i].x = velMag * cosf(theta);
        bVels[i].y = velMag * sinf(theta);
        bAccel[i] = 0;
    }
    
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
    for(int i=0; i<MTABLS_NUM_BALLS; i++){
        
        bool wall = false;
        
        bAccel[i].x = 0;
        bAccel[i].y = 0;
        
        if(bPositions[i].x > _winSize.x - bSizes[i]){
            wall = true;
            float accel = MTABLS_EDGE_HARDNESS * powf((_winSize.x - bSizes[i] - bPositions[i].x), 2);
            bVels[i].x -= accel;
            bAccel[i].x = accel;
        }
        else if(bPositions[i].x < bSizes[i]){
            wall = true;
            float accel = MTABLS_EDGE_HARDNESS * powf((bPositions[i].x - bSizes[i] ), 2);
            bVels[i].x += accel;
            bAccel[i].x = accel;
        }
        if(bPositions[i].y > _winSize.y - bSizes[i]){
            wall = true;
            float accel = MTABLS_EDGE_HARDNESS * powf((_winSize.y - bSizes[i]  - bPositions[i].y), 2);
            bVels[i].y -= accel;
            bAccel[i].y = accel;
        }
        else if(bPositions[i].y < bSizes[i]){
            wall = true;
            float accel = MTABLS_EDGE_HARDNESS * powf((bPositions[i].y - bSizes[i] ), 2);
            bVels[i].y += accel;
            bAccel[i].y = accel;
        }
        
        bAccel[i] /= MTABLS_BALL_SIZE*_winSize.x;
        
        if(!wall){
            float error = bVelIdeal[i] - magnitude(bVels[i]);
            vector_float2 unit = bVels[i] / magnitude(bVels[i]);
            bVels[i] += unit * error * MTABLS_VELCLAMP_kP;
        }
        
        bPositions[i] += bVels[i] * self.animationTimeInterval;
    }
    [self drawInMTKView:_mtkview];
    return;
}

// MAIN LOOP:

- (void)drawInMTKView:(nonnull MTKView *)view {
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Command Buffer";
    
    static const vector_float2 cornerVerts[] = {
        { 1, -1},
        {-1, -1},
        {-1,  1},
        
        { 1, -1},
        {-1,  1},
        { 1,  1},
    };
    
    static const MarchingVertex cornerRealTho[] = {
        {{ 1, -1}, {0, 1, 1, 1} },
        {{-1, -1}, {0, 1, 0, 1} },
        {{-1,  1}, {0, 1, 1, 1} },
        
        {{ 1, -1}, {0, 1, 1, 1} },
        {{-1,  1}, {0, 1, 1, 1} },
        {{ 1,  1}, {0, 0, 1, 1} },
    };
    
    // Que commands for drawing to texture:
    {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderToDistTexRPassDescriptor];
        renderEncoder.label = @"Ball Distance Render Pass";
        [renderEncoder setRenderPipelineState:_renderToDistTexRPipeline];
        
        // Send data in buffers
        [renderEncoder setVertexBytes:&cornerVerts
                               length:sizeof(cornerVerts)
                              atIndex:MTABLS_VERTEX_IN__VERTECIES];
        [renderEncoder setVertexBytes:&_winSize
                               length:sizeof(_winSize)
                              atIndex:MTABLS_VERTEX_IN__SCREENWIDTH];
        
        [renderEncoder setFragmentBytes:&bPositions
                                 length:sizeof(bPositions)
                                atIndex:MTABLS_DIST_FRAGMENT_IN__B_POS];
        [renderEncoder setFragmentBytes:&bSizes
                                 length:sizeof(bSizes)
                                atIndex:MTABLS_DIST_FRAGMENT_IN__B_SIZE];
        [renderEncoder setFragmentBytes:&bAccel
                                 length:sizeof(bAccel)
                                atIndex:MTABLS_DIST_FRAGMENT_IN__B_ACCEL];
        
        // Render triangles
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];
        
        [renderEncoder endEncoding];
    }
    
    
    // Que commands for computing marching cubes.
    {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_rawBallTexRPassDescriptor];
        renderEncoder.label = @"Marching Cubes Render Pass";
        [renderEncoder setRenderPipelineState:_rawBallTexRPipeline];
        
        [renderEncoder setVertexBytes:&cornerRealTho
                               length:sizeof(cornerRealTho)
                              atIndex:MTABLS_VERTEX_IN__VERTECIES];
        
        [renderEncoder setFragmentTexture:_distTexture atIndex:MTABLS_DIST_TEXTURE_IND];
        [renderEncoder setFragmentBytes:&_renderSize
                               length:sizeof(_winSize)
                              atIndex:MTABLS_VERTEX_IN__SCREENWIDTH];
        
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];

        [renderEncoder endEncoding];
    }
    
    MTLRenderPassDescriptor *drawableRenderPassDescriptor = view.currentRenderPassDescriptor;
    {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:drawableRenderPassDescriptor];
        renderEncoder.label = @"Final Output Render Pass";
        
        [renderEncoder setRenderPipelineState:_drawFinalRPipeline];
        
        [renderEncoder setVertexBytes:&cornerVerts
                               length:sizeof(cornerVerts)
                              atIndex:MTABLS_VERTEX_IN__VERTECIES];
        
        [renderEncoder setFragmentTexture:_rawBallTexture atIndex:MTABLS_DIST_TEXTURE_IND];
        [renderEncoder setFragmentBytes:&_winSize
                               length:sizeof(_winSize)
                              atIndex:MTABLS_VERTEX_IN__SCREENWIDTH];
        
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];

        [renderEncoder endEncoding];
    }
    
    //  committing the drawing
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)setFrameSize:(NSSize)newSize {
    [self mtkView:_mtkview drawableSizeWillChange:newSize];
    [super setFrameSize:newSize];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    
    _aspectRatio = size.width / size.height;
    
    _winSize.x = size.width;
    _winSize.y = size.height;
    _renderSize = _winSize * MTABLS_RENDER_SCALE;
    
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
    
    NSError* error;
    
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        os_log_error(OS_LOG_DEFAULT, "Metal is not supported.");
        return false;
    }
    
    _mtkview = [[MTKView alloc] initWithFrame:self.frame device:device];
    _mtkview.delegate = self;
    _mtkview.clearColor = MTLClearColorMake(0, 0, 0, 1);
    
    _commandQueue = [device newCommandQueue];
    _library = MSSNewDefaultBundleLibrary(device);
    
    // Pipeline to calculate distance to each ball on a per-pixel basis and save to a texturue.
    
    MTLTextureDescriptor* distTexDescriptor = [MTLTextureDescriptor new];
    distTexDescriptor.width  = self.frame.size.width*MTABLS_RENDER_SCALE  + 1;
    distTexDescriptor.height = self.frame.size.height*MTABLS_RENDER_SCALE + 1;
    distTexDescriptor.pixelFormat = MTLPixelFormatR16Float;
    distTexDescriptor.usage = MTLTextureUsageRenderTarget |
                          MTLTextureUsageShaderRead;
    
    _distTexture = [device newTextureWithDescriptor:distTexDescriptor];
    
    _renderToDistTexRPassDescriptor = [MTLRenderPassDescriptor new];
    _renderToDistTexRPassDescriptor.colorAttachments[0].texture = _distTexture;
    _renderToDistTexRPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderToDistTexRPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,1);
    _renderToDistTexRPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    // Pipeline to draw distance to balls to the textrue
    MTLRenderPipelineDescriptor* distTexPipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    distTexPipelineStateDescriptor.label = @"Ball Distance Texture Render Pipeline";
    distTexPipelineStateDescriptor.sampleCount = 1;
    distTexPipelineStateDescriptor.vertexFunction =  [_library newFunctionWithName:@"ballDistVertexShader"];
    distTexPipelineStateDescriptor.fragmentFunction =  [_library newFunctionWithName:@"ballDistFragmentShader"];
    distTexPipelineStateDescriptor.colorAttachments[0].pixelFormat = _distTexture.pixelFormat;
    
    _renderToDistTexRPipeline = [device newRenderPipelineStateWithDescriptor:distTexPipelineStateDescriptor error:&error];
    NSAssert(_renderToDistTexRPipeline,  @"Failed to create pipeline state to render to distance texture: %@", error);
    
    // Pipline to perform marching cubes, rendering an un-anti-aliased image to a texture
    
    MTLTextureDescriptor* rawBallTexDescriptor = [MTLTextureDescriptor new];
    rawBallTexDescriptor.width  = self.frame.size.width*MTABLS_RENDER_SCALE;
    rawBallTexDescriptor.height = self.frame.size.height*MTABLS_RENDER_SCALE;
    rawBallTexDescriptor.pixelFormat = MTLPixelFormatRGBA16Float;
    rawBallTexDescriptor.usage = MTLTextureUsageRenderTarget |
                          MTLTextureUsageShaderRead;
    _rawBallTexture = [device newTextureWithDescriptor:rawBallTexDescriptor];
    
    _rawBallTexRPassDescriptor = [MTLRenderPassDescriptor new];
    _rawBallTexRPassDescriptor.colorAttachments[0].texture = _rawBallTexture;
    _rawBallTexRPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _rawBallTexRPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,1);
    _rawBallTexRPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    MTLRenderPipelineDescriptor *marchingCubesPipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    marchingCubesPipelineStateDescriptor.label = @"Marching Cubes Render Pipeline";
    marchingCubesPipelineStateDescriptor.sampleCount = 1;
    marchingCubesPipelineStateDescriptor.vertexFunction = [_library newFunctionWithName:@"marchingCubesVertexShader"];
    marchingCubesPipelineStateDescriptor.fragmentFunction = [_library newFunctionWithName:@"marchingCubesFragmentShader"];
    marchingCubesPipelineStateDescriptor.colorAttachments[0].pixelFormat = _rawBallTexture.pixelFormat;
    
    _rawBallTexRPipeline = [device newRenderPipelineStateWithDescriptor:marchingCubesPipelineStateDescriptor error:&error];
    NSAssert(_rawBallTexRPipeline, @"Failed to create pipeline state to perform marching cubes: %@", error);
    
    // Pipline to render marched cubes to screen and to anti-alias.
    
    MTLRenderPipelineDescriptor *finalRenderPipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    finalRenderPipelineStateDescriptor.label = @"Final Drawing Render Pipeline";
    finalRenderPipelineStateDescriptor.sampleCount = _mtkview.sampleCount;
    finalRenderPipelineStateDescriptor.vertexFunction = [_library newFunctionWithName:@"finalVertexShader"];
    finalRenderPipelineStateDescriptor.fragmentFunction = [_library newFunctionWithName:@"finalFragmentShader"];
    finalRenderPipelineStateDescriptor.colorAttachments[0].pixelFormat = _mtkview.colorPixelFormat;
    
    _drawFinalRPipeline = [device newRenderPipelineStateWithDescriptor:finalRenderPipelineStateDescriptor error:&error];
    NSAssert(_rawBallTexRPipeline, @"Failed to create pipeline state for final render: %@", error);
    
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
