module input;
import std.signals;


Input gInput;

static this() {
	gInput = new Input;
}

class Input {
	enum Key {
		M_LEFT,
		M_RIGHT,
		M_MIDDLE
	};

	enum KeyState {
		UP,
		DOWN,
		PRESS //for printable characters only
    };
	
	mixin Signal!(Key, KeyState);

	struct MouseMove {
		int x, y;
	}
	
	mixin Signal!(MouseMove);
}
