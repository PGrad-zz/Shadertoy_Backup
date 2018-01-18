const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;
const float SPHERE_RADIUS = 1.;

//For each of the CSG logic functions, it is helpful to
//think about a Venn Diagram and calculating the sdf of points
//inside each circle.

//Also known as "nearest". Chooses the closest shape,
//i.e. the most negative/interior of two intersecting shapes.
vec2 csg_union(vec2 shape1, vec2 shape2) {
	vec2 res;
    if(shape1.x < shape2.x)
        res = shape1;
    else
        res = shape2;
    return res;
}

//Chooses the shape with the farthest sdf. This gives the 
//intersection because given 2 intersecting objects and a ray,
//we always choose the furthest away (least negative).
vec2 intersect(vec2 shape1, vec2 shape2) {
	vec2 res;
    if(shape1.x > shape2.x)
        res = shape1;
    else
        res = shape2;
    return res;
}

//A - B is A intersect (negate B)
vec2 diff(vec2 shape1, vec2 shape2) {
    return intersect(shape1, vec2(-shape2.x, 0.));
    
}

float yCylinderSDF( vec3 p, vec3 c )
{
  return length(p.xz-c.xy)-c.z;
}

float xCylinderSDF( vec3 p, vec3 c )
{
  return length(p.yz-c.xy)-c.z;
}

float zCylinderSDF( vec3 p, vec3 c )
{
  return length(p.xy-c.xy)-c.z;
}

//Signed distance function for a box centered at origin.
float boxSDF(vec3 samplePoint, vec3 rt_corner, vec3 c) {
	vec3 dist = abs(samplePoint - c) - rt_corner;
    return min(
        	   max(dist.x, max(dist.y, dist.z)),
               0.
       	   ) 
           + length(max(dist, 0.));
}

/**
 * Signed distance function for a sphere centered at the origin with radius 1.0;
 */
float sphereSDF(vec3 samplePoint, float s, vec3 c) {
    return length(samplePoint - c) - s;
}

float coneSDF( vec3 p, vec3 c ) {
    // c must be normalized
    float q = length(p.xz);
    return dot(c.xy,vec2(q,p.y - c.z));
}

float ellipsoidSDF( in vec3 p, in vec3 r, vec3 c)
{
    return (length( (p - c)/r ) - 1.0) * min(min(r.x,r.y),r.z);
}

vec2 idShape(float dist, float id) {
	return vec2(dist, id); 
}

/**
 * Signed distance function describing the scene.
 * 
 * Absolute value of the return value indicates the distance to the surface.
 * Sign indicates whether the point is inside or outside the surface,
 * negative indicating inside.
 */
vec2 sceneSDF(vec3 samplePoint) {
    float id = 1.;
    vec2 ground = idShape(boxSDF(samplePoint, vec3(50., 0., 50.), vec3(0., -1.1, 0.)), id++);
    vec2 sd_box = idShape(boxSDF(samplePoint, vec3(.5, .3, .5), vec3(0., 0., 0.)), id++);
    vec2 sd_cyl = idShape(yCylinderSDF(samplePoint, vec3(0., .0, .1)), id++);
    vec2 sd_cyl_z = idShape(zCylinderSDF(samplePoint, vec3(0., .2, .718)), id++);
    vec2 sd_cyl_x = idShape(xCylinderSDF(samplePoint, vec3(.2, 0, .718)), id++);
    vec2 cyl_bounded = intersect(sd_cyl,
                       		idShape(sphereSDF(samplePoint, .6, vec3(0., .7, 0.)), id++));
    vec2 cyl_bounded_z = intersect(sd_cyl_z, 
                        	idShape(boxSDF(samplePoint, vec3(.5, 1., .5), vec3(0., -.8, 0.)), id++));
    vec2 cyl_bounded_x = intersect(sd_cyl_x, 
                        	idShape(boxSDF(samplePoint, vec3(.5, 1., .5), vec3(0., -.8, 0.)), id++));
    vec2 ellip = idShape(ellipsoidSDF(samplePoint, vec3(.87, 1.5, .87), vec3(0., 0.4, 0.)), id++);
    vec2 bottom_bound = idShape(boxSDF(samplePoint, vec3(.5, .6,.5), vec3(0., -.95, 0.)), id++);
    vec2 bottom = intersect(ellip, bottom_bound);
    return csg_union(ground,
               csg_union(cyl_bounded,
                         csg_union(
                                   csg_union(cyl_bounded_x,
                                             csg_union(sd_box, cyl_bounded_z)),
                         bottom)
               )
           );
}

vec3 estimateNormal(vec3 p) {
	return normalize(
        		vec3(
                    sceneSDF(vec3(p.x + EPSILON, p.y, p.z)).x - 
                    sceneSDF(vec3(p.x - EPSILON, p.y, p.z)).x,
                    sceneSDF(vec3(p.x, p.y + EPSILON, p.z)).x - 
                    sceneSDF(vec3(p.x, p.y - EPSILON, p.z)).x,
                    sceneSDF(vec3(p.x, p.y, p.z + EPSILON)).x - 
                    sceneSDF(vec3(p.x, p.y, p.z - EPSILON)).x
               	)
           );
}

/**
 * Return the shortest distance from the eyepoint to the scene surface along
 * the marching direction. If no part of the surface is found between start and end,
 * return end.
 * 
 * eye: the eye point, acting as the origin of the ray
 * marchingDirection: the normalized direction to march in
 * start: the starting distance away from the eye
 * end: the max distance away from the ey to march before giving up
 */
vec2 shortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) {
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        vec2 sd = sceneSDF(eye + depth * marchingDirection);
        if (sd.x < EPSILON) {
			return vec2(depth, sd.y);
        }
        depth += sd.x;
        if (depth >= end) {
            return vec2(end, 0.);
        }
    }
    return vec2(end, 0.);
}
            
float lambert(vec3 n, vec3 l) {
	return clamp(dot(n, l), 0., 1.);
}

/**
 * Return the normalized direction to march in from the eye point for a single pixel.
 * 
 * fieldOfView: vertical field of view in degrees
 * size: resolution of the output image
 * fragCoord: the x,y coordinate of the pixel in the output image
 */
vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

vec3 rotate(vec3 p, float angle) {
	return vec3(
        		dot(p.xz, vec2(cos(angle), -sin(angle))),
        		p.y,
        		dot(p.xz, vec2(sin(angle), cos(angle)))
           );
}

mat4 lookAt(vec3 p, vec3 center, vec3 up) {
    vec3 fwd = normalize(center - p);
    
    vec3 strafe = normalize(cross(fwd, up));
    
    vec3 new_up = cross(strafe, fwd);
    
    return mat4(vec4(strafe, 0.),
               	vec4(new_up, 0.),
                vec4(-fwd, 0.),
                vec4(vec3(0.), 1.));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec3 dir = rayDirection(90.0, iResolution.xy, fragCoord);
    float freq = 5.;
    vec3 eye = vec3(0., 1., 0.) + 3. * vec3(cos(iTime * freq), 0., sin(iTime * freq));
    dir = (lookAt(eye, vec3(0.), vec3(0., 1., 0.)) * vec4(dir, 1.)).xyz; 
    vec2 sd = shortestDistanceToSurface(eye, dir, MIN_DIST, MAX_DIST);
    
    float dist = sd.x;
    float type = sd.y;
    vec3 iXPos = eye + dist * dir;
    
    vec3 light = eye;
    vec3 lightDir = normalize(light - iXPos);
    vec3 normal = estimateNormal(iXPos);
    float lambert = lambert(normal, lightDir);
    float ambient = 0.1;
    vec3 color;
    
    // Didn't hit anything
    color = ((dist > MAX_DIST - EPSILON) ? vec3(0.) :
               (type > .5 && type < 1.5) ? vec3(.8, .4, 0.) :
 										   vec3(0., 0., .9)) * (lambert + ambient);
    
    fragColor = vec4(color, 1.0);
}
