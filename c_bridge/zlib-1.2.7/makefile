CC = dmc
CFLAGS  = -6 -o+all -c

OBJS = adler32.obj compress.obj crc32.obj deflate.obj gzclose.obj gzlib.obj gzread.obj \
       gzwrite.obj infback.obj inffast.obj inflate.obj inftrees.obj trees.obj uncompr.obj zutil.obj

.c.obj:
	$(CC) $(CFLAGS) -c -o$@ $<

zlib.lib: $(OBJS)
	lib -c ..\lib\$@ $(OBJS)

clean:
	erase /S *.obj
