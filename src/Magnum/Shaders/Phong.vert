/*
    This file is part of Magnum.

    Copyright © 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019,
                2020 Vladimír Vondruš <mosra@centrum.cz>

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
    THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
*/

#if defined(INSTANCED_OBJECT_ID) && !defined(GL_ES) && !defined(NEW_GLSL)
#extension GL_EXT_gpu_shader4: require
#endif

#ifndef NEW_GLSL
#define in attribute
#define out varying
#endif

#ifdef EXPLICIT_UNIFORM_LOCATION
layout(location = 0)
#endif
uniform highp mat4 transformationMatrix
    #ifndef GL_ES
    = mat4(1.0)
    #endif
    ;

#ifdef EXPLICIT_UNIFORM_LOCATION
layout(location = 1)
#endif
uniform highp mat4 projectionMatrix
    #ifndef GL_ES
    = mat4(1.0)
    #endif
    ;

#if LIGHT_COUNT
#ifdef EXPLICIT_UNIFORM_LOCATION
layout(location = 2)
#endif
uniform mediump mat3 normalMatrix
    #ifndef GL_ES
    = mat3(1.0)
    #endif
    ;
#endif

#ifdef TEXTURE_TRANSFORMATION
#ifdef EXPLICIT_UNIFORM_LOCATION
layout(location = 3)
#endif
uniform mediump mat3 textureMatrix
    #ifndef GL_ES
    = mat3(1.0)
    #endif
    ;
#endif

#if LIGHT_COUNT
/* Needs to be last because it uses locations 10 to 10 + LIGHT_COUNT - 1 */
#ifdef EXPLICIT_UNIFORM_LOCATION
layout(location = 10)
#endif
uniform highp vec3 lightPositions[LIGHT_COUNT]; /* defaults to zero */
#endif

#ifdef EXPLICIT_ATTRIB_LOCATION
layout(location = POSITION_ATTRIBUTE_LOCATION)
#endif
in highp vec4 position;

#if LIGHT_COUNT
#ifdef EXPLICIT_ATTRIB_LOCATION
layout(location = NORMAL_ATTRIBUTE_LOCATION)
#endif
in mediump vec3 normal;

#ifdef NORMAL_TEXTURE
#ifdef EXPLICIT_ATTRIB_LOCATION
layout(location = TANGENT_ATTRIBUTE_LOCATION)
#endif
in mediump vec3 tangent;
#endif
#endif

#ifdef TEXTURED
#ifdef EXPLICIT_ATTRIB_LOCATION
layout(location = TEXTURECOORDINATES_ATTRIBUTE_LOCATION)
#endif
in mediump vec2 textureCoordinates;

out mediump vec2 interpolatedTextureCoordinates;
#endif

#ifdef VERTEX_COLOR
#ifdef EXPLICIT_ATTRIB_LOCATION
layout(location = COLOR_ATTRIBUTE_LOCATION)
#endif
in lowp vec4 vertexColor;

out lowp vec4 interpolatedVertexColor;
#endif

#ifdef INSTANCED_OBJECT_ID
#ifdef EXPLICIT_ATTRIB_LOCATION
layout(location = OBJECT_ID_ATTRIBUTE_LOCATION)
#endif
in highp uint instanceObjectId;

flat out highp uint interpolatedInstanceObjectId;
#endif

#ifdef INSTANCED_TRANSFORMATION
#ifdef EXPLICIT_ATTRIB_LOCATION
layout(location = TRANSFORMATION_MATRIX_ATTRIBUTE_LOCATION)
#endif
in highp mat4 instancedTransformationMatrix;

#ifdef EXPLICIT_ATTRIB_LOCATION
layout(location = NORMAL_MATRIX_ATTRIBUTE_LOCATION)
#endif
in highp mat3 instancedNormalMatrix;
#endif

#ifdef INSTANCED_TEXTURE_OFFSET
#ifdef EXPLICIT_ATTRIB_LOCATION
layout(location = TEXTURE_OFFSET_ATTRIBUTE_LOCATION)
#endif
in mediump vec2 instancedTextureOffset;
#endif

#if LIGHT_COUNT
out mediump vec3 transformedNormal;
#ifdef NORMAL_TEXTURE
out mediump vec3 transformedTangent;
#endif
out highp vec3 lightDirections[LIGHT_COUNT];
out highp vec3 cameraDirection;
#endif

const float distortionData[61] = float[61](
  0,
  0.086897,
  0.14259,
  0.18551,
  0.22175,
  0.25425,
  0.28422,
  0.31204,
  0.33808,
  0.3627,
  0.38626,
  0.40901,
  0.43098,
  0.4522,
  0.4727,
  0.4925,
  0.51164,
  0.53013,
  0.54802,
  0.56533,
  0.58208,
  0.59833,
  0.6141,
  0.62941,
  0.64431,
  0.65883,
  0.67297,
  0.68674,
  0.70016,
  0.71323,
  0.72596,
  0.73837,
  0.75046,
  0.76224,
  0.77373,
  0.78493,
  0.79585,
  0.8065,
  0.8169,
  0.82706,
  0.83698,
  0.84669,
  0.85618,
  0.86548,
  0.87459,
  0.88352,
  0.89228,
  0.90087,
  0.9093,
  0.91758,
  0.92571,
  0.93369,
  0.94153,
  0.94924,
  0.95683,
  0.96429,
  0.97164,
  0.97888,
  0.98601,
  0.99305,
  1
);

float distortionF(float x)
{
  // float x2 = x * x;
  // float x3 = x2 * x;
  // float x4 = x3 * x;
  // float x5 = x4 * x;
  // float x6 = x5 * x;

  // return 
  //   - 27.301 * x6
  //   + 88.820 * x5
  //   - 113.06 * x4
  //   + 72.191 * x3
  //   - 25.494 * x2
  //   + 5.8367 * x + 0.1;

  float angleInDegrees = degrees(atan(x * tan(radians(60.0f))));
  return mix(
    distortionData[uint(floor(angleInDegrees))],
    distortionData[uint(floor(angleInDegrees)) + 1U],
    fract(angleInDegrees));
}

vec4 Distort(vec4 p)
{
    vec2 v = p.xy / p.w;
    // Convert to polar coords:
    float radius = clamp(length(v), 0.0f, 1.0f);

    if (radius <=1)
    {
      float theta = atan(v.y,v.x);
      
      // Distort:
      //radius = pow(radius, 0.5);
      radius = distortionF(radius);

      // Convert back to Cartesian:
      v.x = radius * cos(theta);
      v.y = radius * sin(theta);
      p.xy = v.xy;
      p.xy *= p.w;
      // p.z /= p.w;
      // p.w = 1;
    }
    else
    {
      p.x /= 0.0f;
    }

    return p;
}

void main() {
    /* Transformed vertex position */
    highp vec4 transformedPosition4 = transformationMatrix*
        #ifdef INSTANCED_TRANSFORMATION
        instancedTransformationMatrix*
        #endif
        position;
    highp vec3 transformedPosition = transformedPosition4.xyz/transformedPosition4.w;

    #if LIGHT_COUNT
    /* Transformed normal and tangent vector */
    transformedNormal = normalMatrix*
        #ifdef INSTANCED_TRANSFORMATION
        instancedNormalMatrix*
        #endif
        normal;
    #ifdef NORMAL_TEXTURE
    transformedTangent = normalMatrix*
        #ifdef INSTANCED_TRANSFORMATION
        instancedNormalMatrix*
        #endif
        tangent;
    #endif

    /* Direction to the light */
    for(int i = 0; i < LIGHT_COUNT; ++i)
        lightDirections[i] = normalize(lightPositions[i] - transformedPosition);

    /* Direction to the camera */
    cameraDirection = -transformedPosition;
    #endif

    /* Transform the position */
    gl_Position = projectionMatrix*transformedPosition4;

    #ifdef FOVEATION_DISTORTION
    gl_Position = Distort(gl_Position);
    #endif

    #ifdef TEXTURED
    /* Texture coordinates, if needed */
    interpolatedTextureCoordinates =
        #ifdef TEXTURE_TRANSFORMATION
        (textureMatrix*vec3(
            #ifdef INSTANCED_TEXTURE_OFFSET
            instancedTextureOffset +
            #endif
            textureCoordinates, 1.0)).xy
        #else
        textureCoordinates
        #endif
        ;
    #endif

    #ifdef VERTEX_COLOR
    /* Vertex colors, if enabled */
    interpolatedVertexColor = vertexColor;
    #endif

    #ifdef INSTANCED_OBJECT_ID
    /* Instanced object ID, if enabled */
    interpolatedInstanceObjectId = instanceObjectId;
    #endif
}
