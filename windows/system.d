module windows.system;
import core.sys.windows.windows;
import swizzle;


void HandleEvents() {
	MSG msg;
	while (PeekMessageA(&msg, null, 0, 0, PM_REMOVE | PM_NOYIELD)) {
		if (msg.message == WM_QUIT) {
			gSwizzle.exit();
			break;
		}

		//TranslateMessage(&msg);
		DispatchMessageA(&msg);
	}
}
