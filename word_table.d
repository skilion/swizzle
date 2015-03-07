module word_table;
import std.algorithm, std.array, std.conv, std.math;
import std.stdio, std.string, std.random, std.typecons;

alias Tuple!(int, int) Coord;
immutable int MAX_WORD_LENGTH = 16;
immutable int MIN_WORD_LENGTH = 2;


class WordTable
{
	this(string filename) {
		//Read all words
		auto f = File(filename, "r");
		char[] line;
		line.reserve(32);
		while (f.readln(line)) {
			line = chomp(line);
			line = removechars(line, cast(char[]) "-");
			if (line.length < MIN_WORD_LENGTH) continue;
			if (line.length > MAX_WORD_LENGTH) continue;
			toUpperInPlace(line);
			dictionary[to!string(line)] = 1;
		}
		dictionary.rehash;

		//Words used to construct the table
		words = array(filter!("a.length > 4")(dictionary.keys));

		link.reserve(MAX_WORD_LENGTH);
	}

	void reset() {
		foreach (ref r; table) foreach (ref c; r) c = 0;

		do {
			string word = randomSample(words, 1).front;
			int x = uniform(0, 4);
			int y = uniform(0, 4);
			if (!table[x][y] || table[x][y] == word[0]) {
				table[x][y] = word[0];
				for (int i = 1; i < word.length; i++) {
					int j;
					for (j = 0; j < 16; j++) {
						x += uniform!"[]"(-1, 1);
						y += uniform!"[]"(-1, 1);
						if (x < 0) x = 0;
						if (y < 0) y = 0;
						if (x > 3) x = 3;
						if (y > 3) y = 3;
						if (!table[x][y] || table[x][y] == word[i]) break;
					}
					if (j >= 16) break;
					table[x][y] = word[i];
				}
			}
		} while (!isTableFull());

		findPossibleWords();
	}

	void submitChar(int x, int y) {
		//Ability to remove char
		if (link.length > 1 && link[$ - 2][0] == x && link[$ - 2][1] == y) {
			--link.length;
			--word.length;
			return;
		}
		//Duplicated char
		if (canFind(link, Coord(x, y))) return;
		//Avoid jumps
		if (link.length && (abs(link[$ - 1][0] - x) > 1 || abs(link[$ - 1][1] - y) > 1)) return;

		link ~= Coord(x, y);
		word ~= table[x][y];
	}

	int submitWord() {
		//Compute score
		size_t *p = word in dictionary;
		if (p && *p == 1) {
			*p = 0;
			int score = word.length * 10;
			for (int i = 4; i < word.length; i += 2) {
				score += (word.length - i) * 50;
			}
			return score;
		}
		
		//Already submitted word
		if (p) return -1;

		return 0;
	}

	void clearWord() {
		destroy(link);
		destroy(word);
	}

	const(char)[] getWord() const {
		return word;
	}

	string[] getFoundWords() const {
		string[] words;
		words.reserve(128);
		foreach (key, value; dictionary) {
			if (value == 0) words ~= key;
		}
		return words;
	}

	string[] getPossibleWords() {
		return possibleWords;
	}

	char[4][4] table;
	Coord[] link;


private:
	bool isTableFull() {
		foreach (r; table) foreach (c; r) if (!c) return false;
		return true;
	}

	void findPossibleWords() {
		Coord[MAX_WORD_LENGTH] link;
		clear(possibleWords);
		possibleWords.reserve(512);
		foreach (ref word; dictionary.keys) {
			for (int x = 0; x < 4; x++) {
				for (int y = 0; y < 4; y++) {
					if (tryWord(word, x, y, link[0..0])) {
						possibleWords ~= word;
						goto found;
					}
				}
			}
		found:;
		}
		sort(possibleWords);
	}

	bool tryWord(const(char)[] word, int x, int y, Coord[] link) {
		if (x < 0 || x > 3) return false;
		if (y < 0 || y > 3) return false;
		if (!word.length) return true;
		if (table[x][y] != word[0]) return false;
		if (canFind(link, Coord(x, y))) return false;
		link ~= Coord(x, y);
		if (tryWord(word[1..$], x - 1, y, link)) return true;
		if (tryWord(word[1..$], x + 1, y, link)) return true;
		if (tryWord(word[1..$], x, y - 1, link)) return true;
		if (tryWord(word[1..$], x, y + 1, link)) return true;
		if (tryWord(word[1..$], x - 1, y - 1, link)) return true;
		if (tryWord(word[1..$], x - 1, y + 1, link)) return true;
		if (tryWord(word[1..$], x + 1, y - 1, link)) return true;
		if (tryWord(word[1..$], x + 1, y + 1, link)) return true;
		return false;
	}

	size_t[string] dictionary;
	string[] words; //Words available to construct the table
	char[] word; //Current selected word
	string[] possibleWords, foundWords;
}