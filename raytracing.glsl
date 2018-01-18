vec4 sph_pos = vec4(0., 1., 0., 1.);

float iSphere(vec3 ro, vec3 rd) {
    //Summary:
    //To raytrace the sphere, we calculate where the camera ray hits
    //a sphere of radius r around the origin.
    //An analogy is that you have a block of marble and a laser with
    //finite range. To make a sphere, you "trace" a sphere from the marble.
    //Math:
   	//The equation of a sphere is x^2 + y^2 + z^2 = r^2
    //This can alternatively be stated as |<x,y,z>| = r^2
    //<x,y,z> = ro + t * rd, which implies that
    //t^2 + 2 * dot(ro,rd) * t + |ro| - r^2 = 0
    //If t (the magnitude of the ray) is positive 
    //there is an intersection, because the ray is moving forward.
    //A Pattis diagram:
    // Camera pos
    // ray |
    //   / |
    //  /  |
    // /   |
    // \   |
    //  \  |
    // rad Origin
    float r = 1.;
    float b = 2. * dot(ro, rd);
    float c = dot(ro,ro) - pow(r, 2.);
    
	float t = (pow(b, 2.) - 4. * c) < 0. ? -1.
    					                 : ((-b - sqrt(pow(b, 2.) - 4. * c)) / 2.);
	return t;
}

vec3 nSphere(vec3 iXPos, vec4 sph_pos) {
	return normalize(iXPos / sph_pos.w);
}

float iPlane(vec3 ro, vec3 rd) {
	//For a plane with y=0, the intersection is the x-intercept of the ray
    return -ro.y / rd.y;
}

vec3 nPlane() {
	return vec3(0., 1., 0.);
}

int intersect(vec3 ro, vec3 rd, float far, out float t) {
    //Beware conditional return. This compiler has bugs.
	float tSph = iSphere(ro - sph_pos.xyz, rd);
    float tPla = iPlane(ro, rd);
    
    int type = 0;
    t = far;
    
    if(tSph > 0. && tSph < t) {
    	type = 1;
    	t = tSph;
    }
    
    if(tPla > 0. && tPla < t) {
        type = 2;
    	t = tPla;
    }
    
    return type;
}

//Applying lambert's cosine law. 
float lambert(vec3 n, vec3 l) {
	return clamp(dot(n, l), 0., 1.);
}

float dist(vec2 a, vec2 b) {
	return sqrt(pow(a.x - b.x, 2.) + pow(a.y - b.y, 2.));
}

vec3 mixLight(vec3 matColor, vec3 lightColor, float lambert, float power) {
	return mix(matColor, lightColor, lambert * power);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.xy;
	
    uv *= vec2(iResolution.x / iResolution.y, 1.); //"Contract" the x-axis
    
    sph_pos.xyz += vec3(cos(iTime), 0., sin(iTime));
    
    vec3 ro = vec3(0,1.,3.);
    
    vec2 shift = vec2(.8,.3);
    
    vec3 rd = normalize(vec3(-1. + 2. * uv - shift, -1.));
    
    float t, lightFar = 50.;
    
    int type = intersect(ro, rd, lightFar, t);
    
    vec3 iXPos = vec3(ro + t * rd), lightPos = vec3(1., 3, 2.);
    vec3 lightColor = vec3(0.8, 0.0, 0.0);
    float lightPower = 0.5;
    vec3 color;
    vec3 normal, eye = -rd, light = normalize(lightPos - iXPos);
    
    float ao, lbt;
    
    if(type == 0)
    	color = vec3(0.);
    else {
        if(type == 1) {   
            normal = nSphere(iXPos, sph_pos);
            lbt = lambert(normal, light);
            float ao = 0.2 * (1. + normal.y);
            color = vec3(.5, .4, 8.) * lambert(normal, light) * ao;
        } else {
            float shadow_sph_t;
            normal = nPlane();
            lbt = lambert(normal, light);
            float ambient = 0.05;
            if(intersect(lightPos, -light, lightFar, shadow_sph_t) == 1) {
                vec3 shadow_dir = normalize(sph_pos.xyz - lightPos);
                float shadow_t;
                intersect(lightPos, shadow_dir, lightFar, shadow_t);
            	vec2 shadow_center = (lightPos - light * shadow_t).xz;
                vec2 shadow_pt = (lightPos - light * shadow_sph_t).xz;
                color = vec3(.4, .2, .1) * smoothstep(0., .8, 2. * dist(shadow_pt, shadow_center));
            }
            else
            	color = vec3(.4, .2, .1);
            color *= ambient + lbt;
            
        }
        
        color = lightPower * mixLight(color, lightColor, lbt, lightPower);
    }
    
    fragColor = vec4(color, 1.);
}  
