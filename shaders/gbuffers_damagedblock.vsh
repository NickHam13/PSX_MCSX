#version 420 compatibility
#extension GL_EXT_gpu_shader4 : enable

#define gbuffers_solid
#define gbuffers_terrain
#include "/shaders.settings"
#include "/lib/psx_util.glsl"
#include "/lib/voxel.glsl"

varying vec2 texcoord;
varying vec3 texcoordAffine;
varying vec2 lmcoord;
varying vec4 color;

attribute vec4 mc_Entity;
attribute vec3 at_midBlock;

uniform bool inNether;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform sampler2D lightmap;

#ifdef Floodfill_Enable
	varying vec3 voxelLightColor;
	writeonly layout (rgba8) uniform image2D colorimg4;
	readonly layout (rgba8) uniform image2D colorimg5;
#endif

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	if(inNether)
		lmcoord.r = lmcoord.r * 0.5 + 0.5;
	
	color = gl_Color;

	vec4 vertexPos = gl_Vertex;
	
	// vec4 ftrans = ftransform();
	vec4 ftrans = gl_ModelViewProjectionMatrix * vertexPos;
	float depth = clamp(ftrans.w, 0.001, 1000.0);
	float sqrtDepth = sqrt(depth);


	vec4 position4 = ftrans;

	position4 = PixelSnap(ftrans, vertex_inaccuracy_terrain / sqrtDepth);
	vec3 position = position4.xyz;
	
	float wVal = (mat3(gl_ProjectionMatrix) * position).z;
	wVal = clamp(wVal, -10000.0, 0.0);
	texcoordAffine = vec3(texcoord.xy * wVal, wVal);

	gl_Position = position4;


	// Voxelization
	#ifdef Floodfill_Enable
		vec3 centerPos = gl_Vertex.xyz + at_midBlock/64.0;
		int blockID = int(mc_Entity.x + 0.5);

		ivec3 voxelPos = getPreviousVoxelIndex(centerPos, cameraPosition, previousCameraPosition);
		if(all(greaterThan(abs(at_midBlock), vec3(27.0))))
			voxelPos += ivec3(gl_Normal.xyz);
		if(IsInVoxelizationVolume(voxelPos)) {
			float lightMult = getLightMult(lmcoord.y, lightmap);
			ivec2 voxelIndex = GetVoxelStoragePos(voxelPos);
			voxelLightColor = imageLoad(colorimg5, voxelIndex).rgb * lightMult;
		}
		else {
			voxelLightColor = vec3(0.0);
		}
	#endif
}
