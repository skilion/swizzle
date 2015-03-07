import gl_draw, gl_texture;
import freetype, image;
import std.exception, std.string, std.typecons;

const int FONTMAP_SIZE = 512; //Size (in pixel) of the fontmap, TODO: make this changeable
const int GLYPHS_START = 0x20; //' '
const int GLYPHS_END   = 0x7E; //'~'
const int GLYPHS_COUNT = GLYPHS_END - GLYPHS_START;

private const FT_Int32 smoothModeToFreetypeMode[] = [
	FT_LOAD_TARGET_NORMAL,
	FT_LOAD_TARGET_MONO,
	FT_LOAD_TARGET_LCD
];

private FT_Library library;

static this() {
	enforce(FT_Init_FreeType(&library) == 0, "Can't initialize Freetype");
	//assert(FT_Library_SetLcdFilter(library, FT_LCD_FILTER_DEFAULT));
}

static ~this() {
	FT_Done_FreeType(library);
}



class OpenGLFont
{
	enum SmoothMode {
		NORMAL, //Anti-aliased font
		NONE,	//No smoothing
		LCD		//LCD-optimized font
	};

	this() {
	}

	this(string filename, int size, SmoothMode smoothMode) {
		load(filename, size, smoothMode);
	}

	bool load(string filename, int size, SmoothMode smoothMode) {
		//Create a font face
		if (FT_New_Face(library, filename.toStringz(), 0, &face)) {
			//dbgWarning("Can't load this font file: %s", filename);
			return false;
		}

		if (!face.charmap) {
			//dbgWarning("This font file %s does not contain a unicode charmap", filename);
			return false;
		}

		//Select the font size
		if (size < 8) size = 8;
		if (size > 72) size = 72;
		FT_Set_Char_Size(face, size << 6, size << 6, 96, 96);

		//Set the Freetype load flags
		FT_Int32 loadFlags = FT_LOAD_RENDER | smoothModeToFreetypeMode[smoothMode];

		//Creates the fontmap
		Image image;
		image.create(Image.Format.ALPHA, FONTMAP_SIZE, FONTMAP_SIZE);
		int x = 0, y = 0; //Current position in the fontmap
		int fontmapLineHeight = 0;
		OpenGLTexture texture = new OpenGLTexture();
		for (int i = 0; i < GLYPHS_COUNT; i++)
		{
			FT_Load_Char(face, i + GLYPHS_START, loadFlags);

			FT_GlyphSlot slot = face.glyph;
			FT_Bitmap *bitmap = &slot.bitmap;

			//Check if the character fits in the fontmap
			if (bitmap.width > (FONTMAP_SIZE - x)) {
				x = 0;
				y += fontmapLineHeight + 1;
			}

			//Track the maximum character height
			if (fontmapLineHeight < bitmap.rows) {
				fontmapLineHeight = bitmap.rows;
			}

			//If the character does not fit in the fontmap, save it and create a new one
			if (y > (FONTMAP_SIZE - fontmapLineHeight)) {
				texture.load(image, OpenGLTexture.Filtering.LINEAR);
				texture = new OpenGLTexture();
				image.data[] = 0;

				y = 0;
				fontmapLineHeight = bitmap.rows;
			}

			//Copy the character in the fontmap
			ubyte *pBitmap = bitmap.buffer;
			ubyte *pFontmap = image.data.ptr + x + y * FONTMAP_SIZE;
			if (smoothMode != SmoothMode.NONE) {
				//8-bit bitmap
				for(int j = 0; j < bitmap.rows; j++) {
					pFontmap[0 .. bitmap.width] = pBitmap[0 .. bitmap.width];
					pBitmap += bitmap.pitch;
					pFontmap += FONTMAP_SIZE;
				}
			} else {
				//1-bit bitmap
				for (int j = 0; j < bitmap.rows; j++) {
					for (int k = 0; k < bitmap.width; k++) {
						bool pixel = ((pBitmap[k / 8] << (k % 8)) & 0x80) != 0;
						pFontmap[k] = pixel ? 0xFF : 0;
					}
					pBitmap += bitmap.pitch;
					pFontmap += FONTMAP_SIZE;
				}
			}

			//Save the glyph
			const float ASPECT = 1.0f / FONTMAP_SIZE;
			Glyph *glyph = &glyphs[i];
			glyph.texture = texture;
			glyph.s1 = ASPECT * x;
			glyph.t1 = ASPECT * (y + bitmap.rows);
			glyph.s2 = ASPECT * (x + bitmap.width);
			glyph.t2 = ASPECT * y;
			glyph.width = (smoothMode == SmoothMode.LCD) ? (bitmap.width / 3) : bitmap.width; //LCD-optimized font are 3 times wider
			glyph.height = /*(smoothMode == LCD) ? (bitmap.rows / 3) :*/ bitmap.rows;
			glyph.bearingX = slot.bitmap_left;
			glyph.bearingY = size - slot.bitmap_top;
			glyph.advanceX = slot.advance.x / 64; //1 font unit = 64 pixels

			//Update the current position
			x += bitmap.width + 1;
		}

		//Save the last fontmap
		if (x != 0 || y != 0) {
			texture.load(image, OpenGLTexture.Filtering.LINEAR);
		}

		//Save informations about the font
		this.size = size;
		this.height = face.size.metrics.height / 64; //1 font unit = 64 pixels
		this.kerning = FT_HAS_KERNING(face);

		return true;
	}

	void unload() {
		if (face) {
			FT_Done_Face(face);
			face = null;
			
			OpenGLTexture prev;
			foreach (glyph; glyphs) {
				if (glyph.texture != prev) {
					glyph.texture.unload();
					prev = glyph.texture;
				}
			}
		}
	}
	
	/// \brief Draws the given string.
	/// \param string The string.
	/// \param x The x coordinate.
	/// \param y The y coordinate.
	void drawString(const(char)[] string, int x, int y) const {
		if (!face) return;
		char prevChar = 0;
		//Rebindable!(const OpenGLTexture) prevTexture;
		foreach (char c; string) {
			if ((c >= GLYPHS_START) && (c <= GLYPHS_END)) {
				const Glyph *glyph = &glyphs[c - GLYPHS_START];

				//Bind the fontmap
				//if(glyph.texture != prevTexture) {
				glyph.texture.bind();
				//	prevTexture = glyph.texture;
				//}

				DrawTexturedRect(x + glyph.bearingX,
								 y + glyph.bearingY,
								 glyph.width,
								 glyph.height,
								 glyph.s1, glyph.t1,
								 glyph.s2, glyph.t2);

				x += glyph.advanceX + getKerning(prevChar, c);
				prevChar = c;
			}
		}
	}

	/// Gets the string width in pixel.
	const int getStringWidth(const(char)[] string) {
		if (!face) return 0;
		int width = 0;
		char prevChar = 0;
		foreach (char c; string) {
			if ((c >= GLYPHS_START) && (c <= GLYPHS_END)) {
				width += glyphs[c - GLYPHS_START].advanceX;
				width += getKerning(prevChar, c);
				prevChar = c;
			}
		}

		return width;
	}

	/// Gets the font size in pixel.
	const int getSize() {
		return size;
	}

private:
	/// Gets the kerning between the given characters.
	int getKerning(char left, char right) const {
		if (!kerning) return 0;

		FT_Vector kerning;
		FT_Get_Kerning(face, FT_Get_Char_Index(face, left), FT_Get_Char_Index(face, right), FT_KERNING_DEFAULT, &kerning);

		return kerning.x / 64; //1 font unit = 64 pixels
	}

	struct Glyph {
		OpenGLTexture texture;
		float s1, t1, s2, t2;
		int width, height;		//Glyph size (in pixel)
		int bearingX, bearingY;	//Glyph adjust (in pixel)
		int advanceX;			//Advance width (in pixel)
	}

	FT_Face face;
	int size;  //Requested size (in pixel)
	int height; //Real font size (in pixel)
	bool kerning;

	static const int GLYPHS_START = 0x20; //' '
	static const int GLYPHS_END   = 0x7E; //'~'
	static const int GLYPHS_COUNT = GLYPHS_END - GLYPHS_START;

	Glyph glyphs[GLYPHS_COUNT];
}