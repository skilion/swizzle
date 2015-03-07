CC      = dmc
CFLAGS  = -6 -o+all -c -I../zlib-1.2.7

OBJS =  png.obj pngerror.obj pngget.obj pngmem.obj pngpread.obj \
	pngread.obj pngrio.obj pngrtran.obj pngrutil.obj pngset.obj \
	pngtrans.obj pngwio.obj pngwrite.obj pngwtran.obj pngwutil.obj

.c.obj:
	$(CC) $(CFLAGS) -c -o$@ $<

libpng.lib: $(OBJS)
	lib -c ..\lib\$@ $(OBJS)

clean:
	erase /S *.obj
