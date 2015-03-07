module windows.wndproc;
import core.sys.windows.windows;
import derelict.opengl3.gl;
import input, swizzle;

extern (Windows):

enum WM_ENTERSIZEMOVE = 0x0231;
enum WM_EXITSIZEMOVE = 0x0232;

UINT_PTR SetTimer(HWND, UINT_PTR, UINT, TIMERPROC);
BOOL KillTimer(HWND, UINT_PTR);


nothrow LRESULT WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	scope(failure) return DefWindowProcA(hWnd, message, wParam, lParam);

	switch(message)
	{
	case WM_SIZE:
		int width = LOWORD(lParam);
		int height = HIWORD(lParam);
		glViewport(0, 0, width, height);
		return 0;

	case WM_CLOSE:
		if (MessageBoxA(hWnd, "Do you really want to exit ?", "Swizzle", MB_YESNO) == IDYES) {
			PostQuitMessage(0);
		}
		return 0;
	
	case WM_MOUSEMOVE:
		RECT rect;
		GetClientRect(hWnd, &rect);
		Input.MouseMove mouseMove;
		mouseMove.x = cast(int) ((cast(float) WIDTH / rect.right) * LOWORD(lParam)); 
		mouseMove.y = cast(int) ((cast(float) HEIGHT / rect.bottom) * HIWORD(lParam));
		gInput.emit(mouseMove);
		return 0;
	
	case WM_LBUTTONDOWN:
		gInput.emit(Input.Key.M_LEFT, Input.KeyState.DOWN);
		return 0;

	case WM_LBUTTONUP:
		gInput.emit(Input.Key.M_LEFT, Input.KeyState.UP);
		return 0;

	case WM_MBUTTONDOWN:
		gInput.emit(Input.Key.M_MIDDLE, Input.KeyState.DOWN);
		return 0;

	case WM_MBUTTONUP:
		gInput.emit(Input.Key.M_MIDDLE, Input.KeyState.UP);
		return 0;

	case WM_RBUTTONDOWN:
		gInput.emit(Input.Key.M_RIGHT, Input.KeyState.DOWN);
		return 0;

	case WM_RBUTTONUP:
		gInput.emit(Input.Key.M_RIGHT, Input.KeyState.UP);
		return 0;

	case WM_ENTERSIZEMOVE:
		SetTimer(hWnd, 100, 16, &TimerProc);
		return 0;

	case WM_EXITSIZEMOVE:
		KillTimer(hWnd, 100);
		return 0;

	default:
	}

	return DefWindowProcA(hWnd, message, wParam, lParam);
}

VOID TimerProc(HWND hwnd, UINT uMsg, UINT_PTR idEvent, DWORD dwTime) nothrow
{
	scope(failure) return;
	gSwizzle.frame();
}