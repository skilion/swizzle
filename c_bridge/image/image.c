#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <setjmp.h>
#include "image.h"

/*static jmp_buf jpeg_error_jmp;


/// \brief Overrides the default jpeg message function.
static void jpeg_output_message_override(j_common_ptr cinfo)
{
	char buffer[JMSG_LENGTH_MAX];
	(*cinfo->err->format_message)(cinfo, buffer);
	dbgWarning("libjpeg error: %s", buffer);
}

/// \brief Overrides the default jpeg error function.
static void jpeg_error_exit_override(j_common_ptr cinfo)
{
	jpeg_output_message_override(cinfo);
	jpeg_destroy(cinfo);
	longjmp(jpeg_error_jmp, 1);
}*/

/// \brief Overrides the default png error function.
static void png_error_override(png_structp png_ptr, png_const_charp error_message)
{
	//dbgWarning("libpng error: %s", error_message);
	longjmp(png_jmpbuf(png_ptr), 1);
}

/// \brief Overrides the default png warning function.
static void png_warning_override(png_structp png_ptr, png_const_charp warning_message)
{
	//debugf("libpng warning: %s", warning_message);
}

/*
/// \brief Loads a JPEG image.
/// \param [in] filename The path to the jpeg image.
/// \return true if it succeeds, false if it fails.
bool Image::loadJpeg(const char *filename)
{
	FILE *file = fopen(filename, "rb");
	ASSERT(file);
	
	jpeg_error_mgr error;
	jpeg_decompress_struct decompress;
	JSAMPARRAY rowPointers = nullptr;

	//In case of error libjpeg jumps here
	if(setjmp(jpeg_error_jmp)) {
		jpeg_destroy_decompress(&decompress);
		fclose(file);
		delete [] rowPointers;
		delete [] data;

		format = EMPTY;
		width = height = 0;
		data = nullptr;
		size = 0;
		return false;
	}
	
	//Override default error functions
	decompress.err = jpeg_std_error(&error);
	error.error_exit = jpeg_error_exit_override;
	error.output_message = jpeg_output_message_override;

	//Init libjpeg
	jpeg_create_decompress(&decompress);
	jpeg_stdio_src(&decompress, file);
	
	//Read jpeg header
	jpeg_read_header(&decompress, TRUE);

	//Set target format
	decompress.out_color_space = JCS_RGB;

	//Init decompression
	if(!jpeg_start_decompress(&decompress)) {
		jpeg_destroy_decompress(&decompress);
		dbgWarning("libjpeg: start decompress failed");
		longjmp(jpeg_error_jmp, 1);
	}

	//Some controls
	bool unsupported = false;
	if(decompress.output_components != 3) unsupported = false;
	if(decompress.out_color_components != 3) unsupported = false;
	if(unsupported) {
		jpeg_finish_decompress(&decompress);
		jpeg_destroy_decompress(&decompress);
		debugf("Only RGB JPEG are supported");
		longjmp(jpeg_error_jmp, 1);
	}

	format = RGB;
	width = decompress.output_width;
	height = decompress.output_height;
	
	//Lenght of a row in bytes
	unsigned rowBytes = width * 3;
	size = rowBytes * height;
	data = new uint8[size];
	
	//Create a pointer for each row
	rowPointers = new JSAMPROW[height];
	JSAMPROW p = data;// + rowBytes * (height - 1);
	for(int i = 0; i < height; i++) {
		rowPointers[i] = p;
		p += rowBytes;
	}
	
	while(decompress.output_scanline < decompress.output_height) {
		jpeg_read_scanlines(&decompress, rowPointers + decompress.output_scanline,
			decompress.output_height - decompress.output_scanline);
	}

	jpeg_finish_decompress(&decompress);
	jpeg_destroy_decompress(&decompress);

	delete [] rowPointers;
	return true;
}
*/

int c_LoadPng(const char *filename, int *width, int *height, void **data, size_t *size)
{
	FILE *file = fopen(filename, "rb");
	if (!file) return -1;

	png_bytepp rowPointers = 0;

	//Init the png struct
	png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, 0, png_error_override, png_warning_override);
	if (!png) return -1;

	//Init the info struct
	png_infop info = png_create_info_struct(png);
	if (!info) {
		png_destroy_read_struct(&png, 0, 0);
		return -1;
	}

	//In case of error libpng jumps here
	if (setjmp(png_jmpbuf(png)))  {
		png_destroy_read_struct(&png, &info, 0);
		fclose(file);
		free(rowPointers);
		free(*data);
		*data = NULL;
		*size = 0;
		return -1;
	}

	png_init_io(png, file);
	png_read_info(png, info);

	//Try to always get a RGB or RGBA color type
	switch (png_get_color_type(png, info))
	{
	case PNG_COLOR_TYPE_GRAY:
	case PNG_COLOR_TYPE_GRAY_ALPHA:
		png_set_gray_to_rgb(png);
		break;
	case PNG_COLOR_TYPE_PALETTE:
		png_set_palette_to_rgb(png);
		break;
    }

	//Strip 16 bits precision to 8 bits
	if (png_get_bit_depth(png, info) == 16) png_set_strip_16(png);

	//If the image has a trasparency set convert it to an alpha channel
	if (png_get_valid(png, info, PNG_INFO_tRNS)) png_set_tRNS_to_alpha(png);

	//Update info
	png_read_update_info(png, info);

	int type;
	switch (png_get_color_type(png, info))
	{
	case PNG_COLOR_TYPE_RGB:
		type = PNG_RGB;
		break;
		
	case PNG_COLOR_TYPE_RGB_ALPHA:
		type = PNG_RGBA;
		break;
		
	default:
		png_destroy_read_struct(&png, &info, 0);
		return -1;
	}

	unsigned rowBytes = png_get_rowbytes(png, info);

	*width = png_get_image_width(png, info);
	*height = png_get_image_height(png, info);
	*size = rowBytes * *height;
	*data = malloc(*size);

	rowPointers = malloc(*height * sizeof(png_bytep));
	png_bytep pData = (png_bytep)*data;
	for (int i = *height - 1; i >= 0; i--) {
		rowPointers[i] = pData;
		pData += rowBytes;
	}
	
	png_read_image(png, rowPointers);
	
	free(rowPointers);
	png_destroy_read_struct(&png, &info, 0);
	fclose(file);
    
	return type;
}
