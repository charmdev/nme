#include "./OGL.h"

#define SWAP_RB 0

// 0xAARRGGBB
#if defined(ANDROID)
   #ifdef ANDROID_X86
      #undef SWAP_RB
      static bool SWAP_RB = false;
      static bool sFormatChecked = false;
   #endif
   static int ARGB_STORE = GL_BGRA_EXT;
   static int ARGB_PIXEL = GL_BGRA_EXT;
#elif defined(EMSCRIPTEN) || defined(RASPBERRYPI) || defined(GCW0)
   #undef SWAP_RB
   #define SWAP_RB 1
   #define ARGB_STORE GL_RGBA
   #define ARGB_PIXEL GL_RGBA
#elif defined(IPHONE)
   #define ARGB_STORE GL_RGBA
   #define ARGB_PIXEL GL_BGRA
#elif defined(NME_ANGLE)
   #define ARGB_STORE GL_BGRA_EXT;
   #define ARGB_PIXEL GL_BGRA_EXT;
#elif defined(GCW0)
   #define ARGB_STORE GL_RGBA
   #define ARGB_PIXEL GL_BGRA_EXT
#elif defined(NME_GLES)
   #define ARGB_STORE GL_BGRA
   #define ARGB_PIXEL GL_BGRA
#else
   #define ARGB_STORE GL_RGBA
   #define ARGB_PIXEL GL_BGRA
#endif

//Constant Value:  32993 

namespace nme
{

#ifdef NME_ANGLE
bool gOglAllowRgb = false;
#else
bool gOglAllowRgb = true;
#endif

bool gC0IsRed = true;

#if defined(NME_ANGLE) || defined(EMSCRIPTEN)
#define FORCE_NON_PO2
#endif

bool gFullNPO2Support = false;
bool gPartialNPO2Support = false;


bool NonPO2Supported(bool inNotRepeating)
{
   static bool tried = false;
   
   //OpenGL 2.0 introduced non PO2 as standard, in 2004 - safe to assume it exists on PC
   #ifdef FORCE_NON_PO2
      return true;
   #endif

   if (!tried)
   {
      tried = true;
      const char* extensions = (char*) glGetString(GL_EXTENSIONS);
     
     gFullNPO2Support = strstr(extensions, "ARB_texture_non_power_of_two") != 0;
     
     if (!gFullNPO2Support)
     {
        gPartialNPO2Support = strstr(extensions, "GL_APPLE_texture_2D_limited_npot") != 0;
     }
      
     
      //printf("Full non-PO2 support : %d\n", gFullNPO2Support);
      //printf("Partial non-PO2 support : %d\n", gPartialNPO2Support);
   }

   return (gFullNPO2Support || (gPartialNPO2Support && inNotRepeating));
}


#ifdef ANDROID_X86
void checkRgbFormat()
{
   sFormatChecked = true;
   char data[4];
   glGetError();
   GLuint tid = 0;
   glGenTextures(1, &tid);
   glBindTexture(GL_TEXTURE_2D,tid);
   glTexImage2D(GL_TEXTURE_2D, 0, ARGB_STORE, 1, 1, 0, ARGB_PIXEL, GL_UNSIGNED_BYTE, data);
   int err = glGetError();
   if (err)
   {
      ELOG("Switching texture format for simulator");
      ARGB_STORE = GL_RGBA;
      ARGB_PIXEL = /*GL_BGRA*/ 0x80E1;

      glTexImage2D(GL_TEXTURE_2D, 0, ARGB_STORE, 1, 1, 0, ARGB_PIXEL, GL_UNSIGNED_BYTE, data);
      if (glGetError())
      {
         ELOG("Fall back to software colour transform");
         ARGB_STORE = GL_RGBA;
         ARGB_PIXEL = GL_RGBA;
         SWAP_RB = true;
      }
   }
   glDeleteTextures(1,&tid);
   //else ELOG("Using normal texture format in simulator");
}
#endif



// Type of storage.
// OGLES says this should match the pixel transfer type, but extensions allow
// the RGBA/BGRA swizzel to match the little-endian 4-byte layout
GLenum getTextureStorage(PixelFormat pixelFormat)
{
   switch(pixelFormat)
   {
      case pfRGB:  return gOglAllowRgb ? GL_RGB : ARGB_STORE;
      case pfBGRA:     return ARGB_STORE;
      case pfBGRPremA: return ARGB_STORE;
      case pfAlpha: return GL_ALPHA;
      case pfARGB4444: return GL_RGBA; // GL_RGBA4
      case pfRGB565: return GL_RGB;
      case pfLuma: return GL_LUMINANCE;
      case pfLumaAlpha: return GL_LUMINANCE_ALPHA;
      default: ;
   }
   return 0;
}

GLenum getOglChannelType(PixelFormat pixelFormat)
{
   switch(pixelFormat)
   {
      case pfARGB4444: return GL_UNSIGNED_SHORT_4_4_4_4; // GL_RGBA4
      case pfRGB565: return GL_UNSIGNED_SHORT_5_6_5;
      default:
         return GL_UNSIGNED_BYTE;
   }
}



// Transfer memory layout - in opengl enum
GLenum getTransferOgl(PixelFormat pixelFormat)
{
   switch(pixelFormat)
   {
      case pfRGB:  return gOglAllowRgb ? GL_RGB : ARGB_PIXEL;
      case pfBGRA:     return ARGB_PIXEL;
      case pfBGRPremA: return ARGB_PIXEL;
      case pfAlpha: return GL_ALPHA;
      case pfARGB4444: return GL_UNSIGNED_SHORT_4_4_4_4;
      case pfRGB565: return GL_UNSIGNED_SHORT_5_6_5;
      case pfLuma: return GL_LUMINANCE;
      case pfLumaAlpha: return GL_LUMINANCE_ALPHA;
      default: ;
   }
   return 0;
}

// Gpu memory layout - in our enum, may need to swizzle
PixelFormat getTransferFormat(PixelFormat pixelFormat)
{
   switch(pixelFormat)
   {
      case pfRGB:
         if (gOglAllowRgb)
           return pfRGB;
         // Fallthough

      case pfBGRA:
         return SWAP_RB ? pfRGBA :pfBGRA;

      case pfLuma:
      case pfAlpha:
      case pfLumaAlpha:
      case pfARGB4444:
      case pfRGB565:
         return pixelFormat;


      case pfBGRPremA:
         return SWAP_RB ? pfRGBPremA :pfBGRPremA;

      default: ;
   }
   return pfRGB;
}




class OGLTexture : public Texture
{
   Rect mDirtyRect;
   int  mContextVersion;
   GLuint mTextureID;
   bool mCanRepeat;
   bool mRepeat;
   bool mSmooth;
   bool mMultiplyAlphaOnLoad;
   int mPixelWidth;
   int mPixelHeight;
   int mTextureWidth;
   int mTextureHeight;
   Surface *mSurface;
   GLuint mUploadedFormat;
   bool mMipmaps;


public:
   OGLTexture(Surface *inSurface,unsigned int inFlags)
   {
      #ifdef ANDROID_X86
      if (!sFormatChecked)
         checkRgbFormat();
      #endif

      // No reference count since the surface should outlive us
      mSurface = inSurface;
      mUploadedFormat = 0;
      mMipmaps = inFlags & surfMipmaps;

      mPixelWidth = mSurface->Width();
      mPixelHeight = mSurface->Height();
      bool non_po2 = NonPO2Supported(inFlags & surfNotRepeatIfNonPO2) && !mMipmaps;
      //printf("Using non-power-of-2 texture %d\n",non_po2);

      mTextureWidth = non_po2 ? mPixelWidth : UpToPower2(mPixelWidth);
      mTextureHeight = non_po2 ? mPixelHeight : UpToPower2(mPixelHeight);
      mCanRepeat = IsPower2(mTextureWidth) && IsPower2(mTextureHeight);

      mTextureID = 0;
      glGenTextures(1, &mTextureID);
      CreateTexture();
   }

   void CreateTexture()
   {
      mDirtyRect = Rect(0,0);
      mContextVersion = gTextureContextVersion;

      //__android_log_print(ANDROID_LOG_ERROR, "NME",  "NewTexure %d %d", mTextureWidth, mTextureHeight);

      uint8 *buffer = 0;
      PixelFormat fmt = mSurface->Format();

      GLuint store_format = getTextureStorage(fmt);
      GLuint pixel_format = getTransferOgl(fmt);
      PixelFormat buffer_format = getTransferFormat(fmt);
      GLenum channel= getOglChannelType(fmt);

      int pw = BytesPerPixel(fmt);
      int destPw = BytesPerPixel(buffer_format);

      bool copy_required = mSurface->GetBase() && (mTextureWidth!=mPixelWidth || mTextureHeight!=mPixelHeight || buffer_format!=fmt);

      #if !defined(NME_GLES)
      bool oddRowLength = (mPixelWidth*pw) & 0x3;
      if (oddRowLength)
         copy_required = true;
      #endif

      if (copy_required)
      {
         buffer = (uint8 *)malloc(destPw * mTextureWidth * mTextureHeight);

         PixelConvert( mPixelWidth, mPixelHeight,
              fmt, mSurface->GetBase(), mSurface->GetStride(), mSurface->GetPlaneOffset(),
              buffer_format, buffer, mTextureWidth*destPw, destPw*mTextureWidth*mTextureHeight );

         int extraX =  mTextureWidth - mPixelWidth;
         if (extraX)
            for(int y=0;y<mPixelHeight;y++)
               memset( buffer + (mTextureWidth*y+mPixelWidth)*destPw, 0, destPw*extraX);
         int extraY = mTextureHeight-mPixelHeight;
         if (extraY)
            memset( buffer + mTextureWidth*mPixelHeight*destPw, 0, destPw*mTextureWidth*extraY);
      }

      // __android_log_print(ANDROID_LOG_ERROR, "NME", "CreateTexture %d (%dx%d)",
      //  mTextureID, mPixelWidth, mPixelHeight);
      glBindTexture(GL_TEXTURE_2D,mTextureID);
      mRepeat = mCanRepeat;
      mSmooth = true;
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, mRepeat ? GL_REPEAT : GL_CLAMP_TO_EDGE );
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, mRepeat ? GL_REPEAT : GL_CLAMP_TO_EDGE );
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, mMipmaps ? GL_LINEAR_MIPMAP_NEAREST : GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

      #ifndef NME_GLES
      glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
      #endif

      glTexImage2D(GL_TEXTURE_2D, 0, store_format, mTextureWidth, mTextureHeight, 0, pixel_format, channel, buffer ? buffer : mSurface->GetBase());

      if (mMipmaps)
         glGenerateMipmap(GL_TEXTURE_2D);

      mUploadedFormat = store_format;

      if (buffer)
         free(buffer);

      //int err = glGetError();
      //printf ("GL texture error: %i\n", err);
   }

   ~OGLTexture()
   {
      if (mTextureID && mContextVersion==gTextureContextVersion && HardwareRenderer::current)
      {
         //__android_log_print(ANDROID_LOG_ERROR, "NME", "DeleteTexture %d (%dx%d)",
           //mTextureID, mPixelWidth, mPixelHeight);
         HardwareRenderer::current->DestroyNativeTexture((void *)(size_t)mTextureID);
      }
   }

   int GetWidth() { return mTextureWidth; }
   int GetHeight() { return mTextureHeight; }
   
   //kukuruz
   int getTextureId()
   {
	   return mTextureID;
   }


   void Bind(int inSlot)
   {
      if (inSlot>=0 && CHECK_EXT(glActiveTexture))
      {
         glActiveTexture(GL_TEXTURE0 + inSlot);
      }

      if (gTextureContextVersion!=mContextVersion)
      {
         ELOG("######## Error stale texture");
         CreateTexture();
      }
      else if (mSurface->GetBase() && mDirtyRect.HasPixels())
      {
         //__android_log_print(ANDROID_LOG_INFO, "NME", "UpdateDirtyRect! %d %d",
             //mPixelWidth, mPixelHeight);

         uint8 *buffer = 0;
         PixelFormat fmt = mSurface->Format();

         GLuint store_format = getTextureStorage(fmt);
         if (store_format!=mUploadedFormat)
         {
            CreateTexture();
         }
         else
         {
            glBindTexture(GL_TEXTURE_2D,mTextureID);

            GLuint pixel_format = getTransferOgl(fmt);
            PixelFormat buffer_format = getTransferFormat(fmt);
            GLenum channel= getOglChannelType(fmt);

            int pw = BytesPerPixel(fmt);
            int destPw = BytesPerPixel(buffer_format);


            int x0 = mDirtyRect.x;
            int y0 = mDirtyRect.y;
            int dw = mDirtyRect.w;
            int dh = mDirtyRect.h;

            bool copy_required = buffer_format!=fmt;
            #if defined(NME_GLES)
            if (!copy_required && dw!=mPixelWidth)
            {
               // Formats match but width does not. Can't use GL_UNPACK_ROW_LENGTH.
               //  Do we do the whole row, or copy?
               if (dw>mPixelWidth/2)
               {
                  x0 = 0;
                  if ( (mPixelWidth*pw) & 0x03 )
                     copy_required = true;
                  else
                     dw = mPixelWidth;
               }
               else
                  copy_required = true;
            }
            #endif

            if (copy_required)
            {
               uint8 *buffer = 0;
               // Make unpack align a multiple of 4 ...
               if (destPw<4)
               {
                  dw = (dw + 3) & ~3;
                  if (x0+dw > mPixelWidth)
                  {
                     x0 = mPixelWidth-dw;
                     if (x0<0)
                     {
                        x0 = 0;
                        dw = mPixelWidth;
                     }
                  }
               }

               const uint8 *p0 = mSurface->Row(y0) + x0*pw;
               buffer = (uint8 *)malloc(destPw * dw * dh);
               PixelConvert(dw,dh,
                            fmt, p0, mSurface->GetStride(), mSurface->GetPlaneOffset(),
                            buffer_format, buffer, dw*destPw, dw*dh*destPw );

               glTexSubImage2D(GL_TEXTURE_2D, 0,
                  x0, y0,
                  dw, dh, 
                  pixel_format, channel,
                  buffer );
               free(buffer);
            }
            else
            {
               #ifndef NME_GLES
               glPixelStorei(GL_UNPACK_ROW_LENGTH, mSurface->Width());
               #endif
               glTexSubImage2D(GL_TEXTURE_2D, 0,
                  x0, y0,
                  dw, dh,
                  pixel_format, channel,
                  mSurface->Row(y0) + x0*pw );
               #ifndef NME_GLES
               glPixelStorei(GL_UNPACK_ROW_LENGTH,0);
               #endif
            }

            if (mMipmaps)
               glGenerateMipmap(GL_TEXTURE_2D);

            int err = glGetError();
            if (err != GL_NO_ERROR)
               ELOG("GL Error: %d %dx%d", err, mDirtyRect.w, mDirtyRect.h);
            mDirtyRect = Rect();
         }
      }
      else
         glBindTexture(GL_TEXTURE_2D,mTextureID);
   }

   void BindFlags(bool inRepeat,bool inSmooth)
   {
      if (!mCanRepeat) inRepeat = false;
      if (mRepeat!=inRepeat)
      {
         mRepeat = inRepeat;
         if (mRepeat)
         {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT );
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT );
         }
         else
         {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
         }
      }

      if (mSmooth!=inSmooth)
      {
         mSmooth = inSmooth;
         if (mSmooth)
         {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, mMipmaps ? GL_LINEAR_MIPMAP_NEAREST : GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
         }
         else
         {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
         }
      }

   }


   UserPoint PixelToTex(const UserPoint &inPixels)
   {
      return UserPoint(inPixels.x/mTextureWidth, inPixels.y/mTextureHeight);
   }

   UserPoint TexToPaddedTex(const UserPoint &inTex)
   {
      return UserPoint(inTex.x*mPixelWidth/mTextureWidth, inTex.y*mPixelHeight/mTextureHeight);
   }

   void Dirty(const Rect &inRect)
   {
      if (!mDirtyRect.HasPixels())
         mDirtyRect = inRect;
      else
         mDirtyRect = mDirtyRect.Union(inRect);
   }

   bool IsCurrentVersion() { return mContextVersion==gTextureContextVersion; }
};

//kukuruz

void CreateTexture(GLuint* ID, int format, int width, int height, int size, uint8* data, bool repeat)
{
  *ID = 0;

  glGenTextures(1, ID);
  glBindTexture(GL_TEXTURE_2D, *ID);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, repeat ? GL_REPEAT : GL_CLAMP_TO_EDGE );
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, repeat ? GL_REPEAT : GL_CLAMP_TO_EDGE );
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

  glCompressedTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, size, data);
}

class OGLCompressedTexture : public Texture
{
  GLuint mTextureID;
  GLuint mAlphaID;

  int mContextVersion;

  int mTextureWidth;
  int mTextureHeight;

  CompressedSurface *mSurface;

  bool mRepeat;
  bool mSmooth;
  
  int mSlot;
  
  void BindFlagsForTexture(bool inChangeRepeat, bool inChangeSmooth)
  {
	if (inChangeRepeat)
    {
       if (mRepeat)
       {
          glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
          glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
       }
       else
       {
          glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
          glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
       }
    }
	
	if (inChangeSmooth)
	{
		if (mSmooth)
		{
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		}
		else
		{
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		}
	}  
  }

  public:
    OGLCompressedTexture(CompressedSurface* inSurface) : mTextureID(0), mAlphaID(0)
    {
      mSurface = inSurface;
      mContextVersion = gTextureContextVersion;

      mTextureWidth = mSurface -> Width();
      mTextureHeight = mSurface -> Height();

      mRepeat = true;
	  mSmooth = false;

      CreateTexture(&mTextureID, mSurface -> getDataFormat(), mTextureWidth, mTextureHeight, mSurface -> getDataSize(), mSurface -> getData(), mRepeat);
      if(mSurface -> hasSepAlpha())
        CreateTexture(&mAlphaID, mSurface -> getAlphaFormat(), mTextureWidth, mTextureHeight, mSurface -> getAlphaSize(), mSurface -> getAlpha(), mRepeat);
    }

  ~OGLCompressedTexture()
  {
    if (mTextureID && mContextVersion == gTextureContextVersion && HardwareRenderer::current)
      HardwareRenderer::current -> DestroyNativeTexture((void *)(size_t)mTextureID);

    if (mAlphaID && mContextVersion == gTextureContextVersion && HardwareRenderer::current)
      HardwareRenderer::current -> DestroyNativeTexture((void *)(size_t)mAlphaID);
  }
  
  int getTextureId()
   {
     return mTextureID;
   }
   
   int getAlphaTextureId()
   {
     return mAlphaID;
   }
   
   int GetWidth() { return mTextureWidth; }

   int GetHeight() { return mTextureHeight; }

  void Bind(int inSlot)
  {
      if (inSlot >= 0 && CHECK_EXT(glActiveTexture))
      {
         glActiveTexture(GL_TEXTURE0 + inSlot);
      }
	  
	  /*if (IsCurrentVersion())
	  {
		 ELOG("######## Error stale texture");
		 mContextVersion = gTextureContextVersion;
		 CreateTexture(&mTextureID, mSurface -> getDataFormat(), mTextureWidth, mTextureHeight, mSurface -> getDataSize(), mSurface -> getData(), mRepeat);
         if(mSurface -> hasSepAlpha())
           CreateTexture(&mAlphaID, mSurface -> getAlphaFormat(), mTextureWidth, mTextureHeight, mSurface -> getAlphaSize(), mSurface -> getAlpha(), mRepeat);
	  }*/
	  
      glBindTexture(GL_TEXTURE_2D, mTextureID);

      if (mSurface->hasSepAlpha())
      {
         glActiveTexture(GL_TEXTURE1);
         glEnable(GL_TEXTURE_2D);
         glBindTexture(GL_TEXTURE_2D, mAlphaID);
      }
      
      mSlot = inSlot;
  }
  
  void BindFlags(bool inRepeat, bool inSmooth) 
  {
      bool repeatChanged = (mRepeat != inRepeat);
	   bool smoothChanged = (mSmooth != inSmooth);
	
      mRepeat = inRepeat;
      mSmooth = inSmooth;
      
      // bind flags for color texture
      glBindTexture(GL_TEXTURE_2D, mTextureID);
      BindFlagsForTexture(repeatChanged, smoothChanged);
      
      // bind flags for alpha texture (if there is one)
      if (mSurface->hasSepAlpha())
      {
         glBindTexture(GL_TEXTURE_2D, mAlphaID);
         BindFlagsForTexture(repeatChanged, smoothChanged);
      }
  }

  UserPoint PixelToTex(const UserPoint &inPixels)
  {
    return UserPoint(inPixels.x / mTextureWidth, inPixels.y / mTextureHeight);
  }

  UserPoint TexToPaddedTex(const UserPoint &inTex)
  {
    return UserPoint(inTex.x, inTex.y);
  }

  void Dirty(const Rect &inRect) { }

  bool IsCurrentVersion() { return mContextVersion == gTextureContextVersion; }
};

Texture *OGLCreateTexture(Surface *inSurface,unsigned int inFlags)
{
   if (!inSurface -> isCompressed())
    return new OGLTexture(inSurface,inFlags);
  else
    return new OGLCompressedTexture((CompressedSurface*) inSurface);
}


} // end namespace nme
