module winmain;
import core.runtime;
import core.sys.windows.windows;
import std.string;
import swizzle;


extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    int result;

    try {
        Runtime.initialize();

        result = Dmain();

        Runtime.terminate();
    }
    catch (Throwable o) {
        MessageBoxA(null, o.toString().toStringz(), "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0;		// failed
    }

    return result;
}

int Dmain()
{
	gSwizzle = new Swizzle;
	gSwizzle.run();
	return 0;
}
