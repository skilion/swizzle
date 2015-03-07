import derelict.opengl3.gl;
import std.math;


void SetBlackColor()
{
	glColor3b(0, 0, 0);
}

void SetWhiteColor()
{
	glColor3b(127, 127, 127);
}

void DrawTexturedRect(int x, int y, int width, int height, float s1 = 0, float t1 = 0, float s2 = 1, float t2 = 1)
{
	int x2 = x + width;
	int y2 = y + height;

	glEnable(GL_TEXTURE_2D);

	glBegin(GL_QUADS);
	glTexCoord2f(s1, t2); glVertex2i(x , y );
	glTexCoord2f(s1, t1); glVertex2i(x , y2);
	glTexCoord2f(s2, t1); glVertex2i(x2, y2);
	glTexCoord2f(s2, t2); glVertex2i(x2, y );
	glEnd();

	glDisable(GL_TEXTURE_2D);
}

void DrawLine(int x1, int y1, int x2, int y2, int width)
{
	int xx, yy;
	if (width > 1) {
		float dy = y1 - y2;
		if (dy == 0) {
			yy = width; //Vertical
		} else {
			float dx = x2 - x1;
			if (dx == 0) {
				xx = width; //Horizontal
			} else {
				float m = -1 / (dy / dx);
				xx = cast(int)(width / sqrt((m * m) + 1));
				yy = cast(int)(m * xx);
			}
		}
	}

	glBegin(GL_QUADS);
	glVertex2i(x1 + xx, y1 - yy);
	glVertex2i(x2 + xx, y2 - yy);
	glVertex2i(x2 - xx, y2 + yy);
	glVertex2i(x1 - xx, y1 + yy);
	glEnd();
}