//
//  MetaBallConstants.h
//  MetaBalls
//
//  Created by Parker Hitchcock on 2/2/24.
//

#ifndef MetaBallConstants_h
#define MetaBallConstants_h

// Ball parameters
// Number of balls to be moving around
#define MTABLS_NUM_BALLS 7
// In percentage of viewport
#define MTABLS_BALL_SIZE 0.075
#define MTABLS_BALL_THRESH 0.15
// Average speed in percent of screen per second
#define MTABLS_BALL_SPEED 0.05

#define MTABLS_EDGE_HARDNESS 0.05
#define MTABLS_VELCLAMP_kP 0.5

#define MTABLS_RENDER_SCALE 2
#define MTABLS_DISTTEX_RENDER_SCALE 2

#define MTABLS_SQUARE_SIZE 0.001
#define MTABLS_ANTIALIAS_START -2
#define MTABLS_ANTIALIAS_END    2
// Buffer location constants
#define MTABLS_VERTEX_IN__VERTECIES 0
#define MTABLS_VERTEX_IN__SCREENWIDTH 1

#define MTABLS_DIST_FRAGMENT_IN__B_POS   0
#define MTABLS_DIST_FRAGMENT_IN__B_SIZE  1
#define MTABLS_DIST_FRAGMENT_IN__B_ACCEL  2

#define MTABLS_DIST_TEXTURE_IND 0
#define MTABLS_TIMEDIST_TEXTURE_IND 1

typedef struct {
    vector_float2 position;
    vector_float4 color;
}  MarchingVertex;

#endif /* MetaBallConstants_h */
