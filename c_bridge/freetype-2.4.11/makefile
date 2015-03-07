CC = dmc
CFLAGS = -c -6 -o+all -DFT2_BUILD_LIBRARY -Iinclude

OBJS = \
	src/autofit/autofit.obj \
	src/base/ftapi.obj \
	src/base/ftbase.obj \
	src/base/ftbbox.obj \
	src/base/ftbdf.obj \
	src/base/ftbitmap.obj \
	src/base/ftcid.obj \
	src/base/ftdebug.obj \
	src/base/ftfstype.obj \
	src/base/ftgasp.obj \
	src/base/ftglyph.obj \
	src/base/ftgxval.obj \
	src/base/ftinit.obj \
	src/base/ftlcdfil.obj \
	src/base/ftmm.obj \
	src/base/ftpatent.obj \
	src/base/ftpfr.obj \
	src/base/ftstroke.obj \
	src/base/ftsynth.obj \
	src/base/ftsystem.obj \
	src/base/fttype1.obj \
	src/base/ftwinfnt.obj \
	src/base/ftxf86.obj \
	src/bdf/bdf.obj \
	src/cache/ftcache.obj \
	src/cff/cff.obj \
	src/cid/type1cid.obj \
	src/gzip/ftgzip.obj \
	src/lzw/ftlzw.obj \
	src/pcf/pcf.obj \
	src/pfr/pfr.obj \
	src/psaux/psaux.obj \
	src/pshinter/pshinter.obj \
	src/psnames/psnames.obj \
	src/raster/raster.obj \
	src/sfnt/sfnt.obj \
	src/smooth/smooth.obj \
	src/truetype/truetype.obj \
	src/type1/type1.obj \
	src/type42/type42.obj \
	src/winfonts/winfnt.obj

.c.obj:
	$(CC) $(CFLAGS) -c -o$@ $<

freetype.lib: $(OBJS)
	lib -c ..\lib\$@ $(OBJS)

clean:
	erase /S *.obj
