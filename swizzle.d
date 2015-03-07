import core.thread, core.time;
import core.sys.windows.windows;
import derelict.opengl3.gl;
import gl_draw, gl_font, gl_texture;
import image, input, word_table;
import std.algorithm, std.conv, std.random;
import windows.gl_window, windows.system, windows.wndproc;

pragma(lib, "Winmm.lib"); //PlaySoundA

Swizzle gSwizzle;


immutable int WIDTH = 500;
immutable int HEIGHT = 500;
immutable Duration FLASH_DURATION = dur!"msecs"(500);
immutable Duration MATCH_DURATION = dur!"seconds"(150);


class Swizzle
{
	void run() {
		window = new OpenGLWindow;
		window.setTitle("Swizzle");
		window.setSize(WIDTH, HEIGHT);
		window.setWndProc(&WndProc);
		window.create();

		gInput.connect(&keyHandler);
		gInput.connect(&mouseHandler);

		glViewport(0, 0, WIDTH, HEIGHT);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, WIDTH, HEIGHT, 0, -1, 1);

		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();

		glDisable(GL_DEPTH_TEST);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		OpenGLTexture splash = new OpenGLTexture(Image("data/splash.png"), OpenGLTexture.Filtering.LINEAR);
		splash.bind();
		SetWhiteColor();
		DrawTexturedRect(0, 0, WIDTH, HEIGHT);
		window.swapBuffers();
		Thread.sleep(dur!("seconds")(2));
		
		load();
		newGame();

		while (!shouldExit) {
			HandleEvents();
			frame();
			Thread.sleep(dur!("msecs")(16));
		}

		unload();
		window.destroy();
	}

	void exit() {
		shouldExit = true;
	}

	void frame() {
		glClear(GL_COLOR_BUFFER_BIT);
		SetWhiteColor();
		backTexture.bind();
		DrawTexturedRect(0, 0, WIDTH, HEIGHT);

		switch (status)
		{
		case Status.IN_GAME:
			gameFrame();
			break;

		case Status.END_GAME:
			endGameFrame();
			break;

		case Status.RESULTS:
			resultsFrame();
			break;

		default:
		}

		window.swapBuffers();
	}

private:
	void newGame() {
		score = 0;
		status = Status.IN_GAME;
		table.reset();

		//Reset time
		matchTick = TickDuration.currSystemTick();
	}

	void gameFrame() {
		//Logic
		if (flashTick != TickDuration(0)) {
			if (cast(Duration)(TickDuration.currSystemTick() - flashTick) > FLASH_DURATION) {
				flashTick = TickDuration(0);
				table.clearWord();
			}
		}

		Duration timeLeft = MATCH_DURATION - cast(Duration)(TickDuration.currSystemTick() - matchTick);
		if(timeLeft.isNegative()) {
			endGame();
			timeLeft = Duration.init;
		}

		//Draw link
		glColor3f(1, 0.75f, 0);
		for (int i = 0; (i + 1) < table.link.length; i++) {
			DrawLine(32 + 50 + table.link[i][0] * 112,
					 52 + 50 + table.link[i][1] * 112,
					 32 + 50 + table.link[i + 1][0] * 112,
					 52 + 50 + table.link[i + 1][1] * 112,
					 16);
		}

		//Buttons
		for (int i = 0; i < 4; i++) {
			for (int j = 0; j < 4; j++) {
				bool flash;
				if (cast(Duration)(TickDuration.currSystemTick() - flashTick) <= FLASH_DURATION) {
					if (canFind(table.link, Coord(i, j))) flash = true;
				}
				if (immButton(32 + i * 112, 52 + j * 112, flash, table.table[i][j])) {
					table.submitChar(i, j);
				}
			}
		}

		//Time left
		string time = to!string(timeLeft.minutes) ~ ":" ~ to!string(timeLeft.seconds % 60);
		SetBlackColor();
		fancyFont.drawString(time, 32, 2);
		SetWhiteColor();
		fancyFont.drawString(time, 30, 0);
		clockTexture.bind();
		DrawTexturedRect(4, 4, 32, 32);
		
		//Score
		string scoreSrt = to!string(score);
		int scoreStrWidth = stdFont.getStringWidth(scoreSrt);
		SetBlackColor();
		fancyFont.drawString(scoreSrt, (WIDTH - scoreStrWidth - 18), 2);
		SetWhiteColor();
		fancyFont.drawString(scoreSrt, (WIDTH - scoreStrWidth - 16), 0);

		//Current word
		if (table.getWord().length) {
			int width = stdFont.getStringWidth(table.getWord());
			int x = (WIDTH - width) / 2;
			glColor3f(1, 0.75f, 0);
			glBindTexture(GL_TEXTURE_2D, 0);
			DrawTexturedRect(x - 2, 4, width + 4, 24);
			SetBlackColor();
			stdFont.drawString(table.getWord(), (WIDTH - width) / 2, 6);
		}
	}

	void endGame() {
		status = Status.END_GAME;
		shift = 0;
		PlaySoundA("data/end_game.wav", null, SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
	}

	void endGameFrame() {
		//Buttons
		for (int i = 0; i < 4; i++) {
			for (int j = 0; j < 4; j++) {
				immButton(32 + i * 112, shift + 52 + j * 112, false, table.table[i][j]);
			}
		}

		shift += (shift / 5) + 1;
		if (shift >= WIDTH * 2) {
			computeResults();
		}
	}

	void computeResults() {
		status = Status.RESULTS;
		shift = 0;
		foundWords = table.getFoundWords();
		possibleWords = table.getPossibleWords();
	}

	void resultsFrame() {
		SetWhiteColor();
		int width = fancyFont.getStringWidth("Game over");
		fancyFont.drawString("Game over", (WIDTH - width) / 2, 12);
		stdFont.drawString("Score: " ~ to!string(score), 100, 60);
		stdFont.drawString("Words found: " ~ to!string(foundWords.length) ~ "/" ~ to!string(possibleWords.length), 100, 90);
		
		//Word list
		immutable int BEGIN_HEIGHT = 140;
		immutable int STR_HEIGHT = 15;
		int wordNum = shift / STR_HEIGHT;
		int beginShift = shift % STR_HEIGHT;
		float alpha = 1 - beginShift / cast(float) STR_HEIGHT;
		for (int y = BEGIN_HEIGHT + STR_HEIGHT - beginShift; y < WIDTH; y += STR_HEIGHT) {
			wordNum %= possibleWords.length;
			string word = possibleWords[wordNum++];
			if (canFind(foundWords, word)) glColor4f(1, 1, 1, alpha);
			else glColor4f(0.6f, 0.6f, 0.6f, alpha);
			alpha = 1;
			smallFont.drawString(word, WIDTH / 3, y);
		}
		shift++;
	}

	void keyHandler(Input.Key key, Input.KeyState keyState) {
		if (key == Input.Key.M_LEFT) {
			mouseClick = keyState != Input.KeyState.UP;
			if (keyState == Input.KeyState.UP) {
				if (status == Status.IN_GAME) {
					//Word complete
					int tmp = table.submitWord();
					if (tmp < 0) {
						PlaySoundA("data/old_word.wav", null, SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
						table.clearWord();
					} else if (tmp == 0) {
						table.clearWord();
					} else if (tmp > 0) {
						score += tmp;
						flashTick = TickDuration.currSystemTick();
						PlaySoundA("data/new_word.wav", null, SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
					}
				} else if (status == Status.RESULTS) newGame();
			}
		}
	}

	void mouseHandler(Input.MouseMove mouseMove) {
		mouseX = mouseMove.x;
		mouseY = mouseMove.y;
	}

	bool immButton(int x, int y, bool active, char c) {
		//Click & focus
		bool clicked, focus;
		if (mouseX > x + 4 && mouseX < x + 96) {
			if (mouseY > y + 4 && mouseY < y + 96) {
				focus = true;
				if(mouseClick) clicked = true;
			}
		}

		//Draw button
		if(active || clicked) glColor3f(1, 0.75f, 0);
		else SetWhiteColor();
		buttonTexture.bind();
		if(focus) DrawTexturedRect(x - 4, y - 4, 108, 108);
		else DrawTexturedRect(x, y, 100, 100);
		
		//Draw character
		string strC = to!string(c);
		int width = keysFont.getStringWidth(strC);
		int adjX = (100 - width) / 2;
		SetBlackColor();
		keysFont.drawString(strC, x + adjX, y + 18);

		return clicked;
	}

	void load() {
		table = new WordTable("data/ita.txt");

		//Textures
		backTexture = new OpenGLTexture(Image("data/back.png"), OpenGLTexture.Filtering.LINEAR);
		clockTexture = new OpenGLTexture(Image("data/clock.png"), OpenGLTexture.Filtering.LINEAR);
		buttonTexture = new OpenGLTexture(Image("data/button.png"), OpenGLTexture.Filtering.LINEAR);

		//Fonts
		smallFont = new OpenGLFont("data/Verdana.ttf", 12, OpenGLFont.SmoothMode.NORMAL);
		stdFont = new OpenGLFont("data/Verdana.ttf", 20, OpenGLFont.SmoothMode.NORMAL);
		fancyFont = new OpenGLFont("data/Comicv3.ttf", 26, OpenGLFont.SmoothMode.NORMAL);
		keysFont = new OpenGLFont("data/Verdana.ttf", 60, OpenGLFont.SmoothMode.NORMAL);
	}

	void unload() {
		//Fonts
		keysFont.unload();
		fancyFont.unload();
		stdFont.unload();
		smallFont.unload();

		//Textures
		buttonTexture.unload();
		clockTexture.unload();
		backTexture.unload();

		destroy(table);
	}

	enum Status {
		IN_GAME,
		END_GAME,
		RESULTS
	};

	//Game
	bool shouldExit;
	Status status;
	WordTable table;
	int score;
	TickDuration flashTick;
	TickDuration matchTick;

	//End game
	int shift;

	//Results
	string[] possibleWords, foundWords;

	//Input
	int mouseX, mouseY;
	bool mouseClick;
	
	OpenGLWindow window;
	OpenGLTexture backTexture, clockTexture, buttonTexture;
	OpenGLFont smallFont, stdFont, fancyFont, keysFont;
}