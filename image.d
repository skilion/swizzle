module image;
import core.memory: GC;
import std.algorithm;
import std.stdio;
import std.string;
import swizzle;

pragma (lib, "lib\\libz.lib");
pragma (lib, "lib\\image.lib");
pragma (lib, "lib\\libpng.lib");


struct Image
{
public:
	enum Format {
		EMPTY,
		RGB,
		RGBA,
		ALPHA	
	};
	
	Format format;
	int width, height;
	ubyte[] data;

	this(string filename) {
		load(filename);
	}

	/// \brief Loads the given image file.
	bool load(string filename)
	{
		if (!isEmpty()) return false;

		auto file = File(filename, "rb");
		if (!file.isOpen()) return false;

		byte[8] header;
		file.rawRead(header);
		file.close();

		if (header[0..2] == ['B', 'M']) return loadBitmap(filename);
		if (png_sig_cmp(header.ptr, 0, 8) == 0) return loadPng(filename);

		return false;
	}

	const bool isEmpty() {
		return format == Format.EMPTY;
	}

	/// Creates an empty image.
	void create(Format format, int width, int height)
	{
		this.format = format;
		this.width = width;
		this.height = height;
		data.length = width * height * getBytesPerPixel();
	}

	/// Gets the size in bytes of one pixel.
	int getBytesPerPixel() const
	{
		with (Format)
		switch (format)
		{
		default:
		case EMPTY:	return 0;
		case RGB:	return 3;
		case RGBA:	return 4;
		case ALPHA: return 1;
		}
	}


private:
	align (1)
	struct BmpHeader {
		ubyte	signature[2];
		uint	fileSize;
		ushort	creator1;
		ushort	creator2;
		uint	offset;
	};

	align (1)
	struct BmpDibHeaderV3 {
		uint	headerSize;
		uint	width;
		uint	height;
		ushort	planes;
		ushort	bpp;
		uint	compression;
		uint	bmpSize;
		uint	hres;
		uint	vres;
		uint	nColors;
		uint	nImpColors;
	};

	bool loadBitmap(string filename) {
		File file = File(filename, "rb");
		assert(file.isOpen());

		BmpHeader bmpHeader;
		BmpDibHeaderV3 bmpDibHeader;
		file.rawRead((&bmpHeader)[0..1]);
		file.rawRead((&bmpDibHeader)[0..1]);

		bool unsupported = false;
		if (bmpHeader.fileSize != file.size()) unsupported = true;
		if (bmpDibHeader.height <= 0) unsupported = true;
		if (bmpDibHeader.width <= 0) unsupported = true;
		if (bmpDibHeader.planes != 1) unsupported = true;
		if (bmpDibHeader.compression != 0) unsupported = true;
		if (bmpDibHeader.bpp != 24) unsupported = true;
		if (max(bmpDibHeader.width, bmpDibHeader.height) > 4096) return false;
		if (bmpDibHeader.width * bmpDibHeader.height * 3 != bmpDibHeader.bmpSize) return false;
		if (unsupported) return false;

		format = Format.RGB;
		width = bmpDibHeader.width;
		height = bmpDibHeader.height;
		data.length = bmpDibHeader.bmpSize;
		file.seek(bmpHeader.offset);
		file.rawRead(data);
		file.close();

		//NOTE: Pixels are stored starting in the lower left corner, going from
		//      left to right, and then row by row from the bottom to the top of the image.
		//      Each row is extended to a 32-bit (4-bit) boundary.

		//unsigned padding = rowBytes - width * 3;
		
		//BGR to RGB
		ubyte *p = data.ptr;
		for (int i = 0; i < data.length; i += 3) {
			swap(p[0], p[2]);
			p += 3;
		}

		return true;
	}

	bool loadPng(string filename) {
		uint size;
		void *data;

		int result = c_LoadPng(filename.toStringz(), &width, &height, &data, &size);
		switch (result)
		{
		case PNG_RGB:
			format = Format.RGB;
			break;

		case PNG_RGBA:
			format = Format.RGBA;
			break;

		default:
			return false;
		}
		
		GC.addRange(data, size);
		this.data = cast(ubyte[]) data[0..size];
		
		return true;
	}
}


private:
const int PNG_RGB = 0;
const int PNG_RGBA = 1;

extern (C)
int png_sig_cmp(const byte *sig, size_t start, size_t num_to_check);

extern (C)
int c_LoadPng(const char *filename, int *width, int *height, void **data, uint *size);
