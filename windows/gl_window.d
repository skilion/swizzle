module windows.gl_window;
import derelict.opengl3.gl;
import fix = derelict.opengl3.wgl;
import core.time;
import core.sys.windows.windows;
import std.conv;
import std.string;

pragma (lib, "gdi32.lib");
pragma (lib, "user32.lib");
pragma (lib, "DerelictGL.lib");
pragma (lib, "DerelictUtil.lib");

extern(Windows) BOOL UnregisterClassA(LPCTSTR lpClassName, HINSTANCE hInstance);
extern(Windows) BOOL SetRect(LPRECT lprc, int xLeft, int yTop, int xRight, int yBottom);

static this() {
	DerelictGL.load();
}


class OpenGLWindow
{
	this() {
		WNDPROC wndProc = &DefWindowProcA;
		hInstance = GetModuleHandleA(null);
		wndClassName = "gl_window_" ~ to!string(TickDuration.currSystemTick().length);
	}

	void setTitle(string title) {
		this.title = title;
	}

	void setSize(int width, int height) {
		this.width = width;
		this.height = height;
	}

	void setWndProc(WNDPROC wndProc) {
		this.wndProc = wndProc;
	}

	void create() {
		registerClass();
		createWindow();
		createContext();
		makeCurrent();
	}

	void destroy() {
		destroyContext();
		destroyWindow();
		unregisterClass();
	}
	
	void makeCurrent() {
		fix.wglMakeCurrent(hDC, hGLRC);
	}

	void swapBuffers() {
		SwapBuffers(hDC);
	}


protected:
	string title, wndClassName;
	int width = 100, height = 100;
	HINSTANCE hInstance;
	WNDPROC wndProc;
	HWND hWnd;
	HDC hDC;
	HGLRC hGLRC;


private:
	void registerClass() {
		WNDCLASSEXA wc;
		wc.cbSize			= WNDCLASSEXA.sizeof;
		wc.style			= CS_VREDRAW | CS_HREDRAW | CS_OWNDC;
		wc.lpfnWndProc		= wndProc;
		wc.hInstance		= hInstance;
		wc.hIcon			= LoadIconA(hInstance, cast(LPSTR)101);
		wc.hbrBackground	= GetStockObject(BLACK_BRUSH);
		wc.hCursor			= LoadCursorA(null, IDC_ARROW);
		wc.lpszClassName	= wndClassName.toStringz();
		
		if (!RegisterClassExA(&wc)) throw new Exception("Can't register the window class");
	}

	void unregisterClass() {
		UnregisterClassA(wndClassName.toStringz(), hInstance);
	}

	void createWindow() {
		DWORD exstyle = 0;
		DWORD style = WS_OVERLAPPEDWINDOW;
		/*if(fullscreen) {
			exstyle = WS_EX_TOPMOST;
			style = WS_POPUP;
		}*/
		style |= WS_CLIPCHILDREN | WS_CLIPSIBLINGS | WS_VISIBLE;

		//Adjust the window size
		RECT rect;
		SetRect(&rect, 0, 0, width, height);
		AdjustWindowRectEx(&rect, style, 0, exstyle);
		int adjustedWidth = rect.right - rect.left;
		int adjustedHeight = rect.bottom - rect.top;

		//Center the window on the desktop
		int x = (GetSystemMetrics(SM_CXSCREEN) - adjustedWidth) / 2;
		int y = (GetSystemMetrics(SM_CYSCREEN) - adjustedHeight) / 2;
		
		//Create the window
		hWnd = CreateWindowExA(exstyle, wndClassName.toStringz(), title.toStringz(),
							  style, x, y, adjustedWidth, adjustedHeight,
							  null, null, hInstance, null);

		if (!hWnd) throw new Exception("Can't create the main window");

		hDC = GetDC(hWnd);
		if (!hDC) throw new Exception("Can't retrieve the device context");
	}

	void destroyWindow() {
		ReleaseDC(hWnd, hDC);
		DestroyWindow(hWnd);
		
		hDC = null;
		hWnd = null;
	}

	void createContext() {
		PIXELFORMATDESCRIPTOR pfd;
		pfd.nSize			= PIXELFORMATDESCRIPTOR.sizeof;
		pfd.nVersion		= 1;
		pfd.dwFlags			= PFD_DOUBLEBUFFER | PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL; //PFD_GENERIC_ACCELERATED
		pfd.iPixelType		= PFD_TYPE_RGBA; 
		pfd.cColorBits		= 32;//colorDepth;
		pfd.cDepthBits		= 16;//depth;
		pfd.cStencilBits	= 4;

		int pixelFormat = ChoosePixelFormat(hDC, &pfd);
		if (!pixelFormat) throw new Exception("Can't find an appropriate pixel format");
		if (!SetPixelFormat(hDC, pixelFormat, &pfd)) throw new Exception("Can't set the specified pixel format");

		hGLRC = fix.wglCreateContext(hDC);
		if (!hGLRC) throw new Exception("Can't create a new OpenGL render context");
	}

	void destroyContext() {
		fix.wglMakeCurrent(null, null);
		fix.wglDeleteContext(hGLRC);
		hGLRC = null;
	}
};
