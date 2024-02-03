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
    
    id<MTLRenderPipelineState> _drawMarchingCubesRPipeline;
    
    float _aspectRatio;
    vector_float2 _winSize;
    
    vector_float2 bPositions[MTABLS_NUM_BALLS];
    float bSizes[MTABLS_NUM_BALLS];
    vector_float2 bVels[MTABLS_NUM_BALLS];
    float bVelIdeal[MTABLS_NUM_BALLS];
    
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
        
        if(bPositions[i].x > _winSize.x - bSizes[i]){
            wall = true;
            bVels[i].x -= MTABLS_EDGE_HARDNESS * powf((_winSize.x - bSizes[i] - bPositions[i].x), 2);
        }
        else if(bPositions[i].x < bSizes[i]){
            wall = true;
            bVels[i].x += MTABLS_EDGE_HARDNESS * powf((bPositions[i].x - bSizes[i] ), 2);
        }
        if(bPositions[i].y > _winSize.y - bSizes[i]){
            wall = true;
            bVels[i].y -= MTABLS_EDGE_HARDNESS * powf((_winSize.y - bSizes[i]  - bPositions[i].y), 2);
        }
        else if(bPositions[i].y < bSizes[i]){
            wall = true;
            bVels[i].y += MTABLS_EDGE_HARDNESS * powf((bPositions[i].y - bSizes[i] ), 2);
        }
        
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
//        [renderEncoder setVertexBytes:&_aspectRatio
//                               length:sizeof(_aspectRatio)
//                              atIndex:MTABLS_VERTEX_IN__ASPECT];
        [renderEncoder setVertexBytes:&_winSize
                               length:sizeof(_winSize)
                              atIndex:MTABLS_VERTEX_IN__SCREENWIDTH];
        [renderEncoder setFragmentBytes:&bPositions
                                 length:sizeof(bPositions)
                                atIndex:MTABLS_DIST_FRAGMENT_IN__B_POS];
        [renderEncoder setFragmentBytes:&bSizes
                                 length:sizeof(bSizes)
                                atIndex:MTABLS_DIST_FRAGMENT_IN__B_SIZE];
        
        // Render triangles
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];
        
        [renderEncoder endEncoding];
    }
    
    MTLRenderPassDescriptor *drawableRenderPassDescriptor = view.currentRenderPassDescriptor;
    // Que commands for drawing to screen:
    {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:drawableRenderPassDescriptor];
        renderEncoder.label = @"Marching Cubes Render Pass";
        
        [renderEncoder setRenderPipelineState:_drawMarchingCubesRPipeline];
        
        [renderEncoder setVertexBytes:&cornerRealTho
                               length:sizeof(cornerRealTho)
                              atIndex:MTABLS_VERTEX_IN__VERTECIES];
//        [renderEncoder setVertexBytes:&_aspectRatio
//                               length:sizeof(_aspectRatio)
//                              atIndex:MTABLS_VERTEX_IN__ASPECT];

        
        [renderEncoder setFragmentTexture:_distTexture atIndex:MTABLS_DIST_TEXTURE_IND];
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
    
    
    MTLTextureDescriptor* distTexDescriptor = [MTLTextureDescriptor new];
    distTexDescriptor.width  = self.frame.size.width  + 1;
    distTexDescriptor.height = self.frame.size.height + 1;
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
    
    // Pipline to render the distance to ball texture to the screen.
    // Will perform marching cubes
    MTLRenderPipelineDescriptor *marchingCubesPipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    marchingCubesPipelineStateDescriptor.label = @"Marching Cubes Render Pipeline";
    marchingCubesPipelineStateDescriptor.sampleCount = _mtkview.sampleCount;
    marchingCubesPipelineStateDescriptor.vertexFunction = [_library newFunctionWithName:@"marchingCubesVertexShader"];
    marchingCubesPipelineStateDescriptor.fragmentFunction = [_library newFunctionWithName:@"marchingCubesFragmentShader"];
    marchingCubesPipelineStateDescriptor.colorAttachments[0].pixelFormat = _mtkview.colorPixelFormat;
    
    _drawMarchingCubesRPipeline = [device newRenderPipelineStateWithDescriptor:marchingCubesPipelineStateDescriptor error:&error];
    NSAssert(_drawMarchingCubesRPipeline, @"Failed to create pipeline state to render to screen: %@", error);
    
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
