module gl_texture;
import derelict.opengl3.gl;
import image;

private const GLenum formatToOpenGLFormat[] = [0, GL_RGB, GL_RGBA, GL_ALPHA];
private const GLenum filteringToOpenGLFiltering[] = [GL_NEAREST, GL_LINEAR];


class OpenGLTexture
{
	enum Filtering {
		NEAREST,
		LINEAR
	};

	GLuint textureName;

	this() {
	}

	this(Image image, Filtering filtering) {
		load(image, filtering);
	}

	bool load(Image image, Filtering filtering) {
		if(image.isEmpty()) {
			unload();
			return true;
		}
		
		if (textureName == 0) glGenTextures(1, &textureName);
		glBindTexture(GL_TEXTURE_2D, textureName);

		GLenum glFiltering = filteringToOpenGLFiltering[filtering];
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, glFiltering);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, glFiltering);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);//GL_REPEAT
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);//GL_REPEAT
		
		GLenum format = formatToOpenGLFormat[image.format];
		glTexImage2D(GL_TEXTURE_2D, 0, format, image.width, image.height,
					 0, format, GL_UNSIGNED_BYTE, image.data.ptr);
		
		return true;
	}

	void unload() {
		glDeleteTextures(1, &textureName);
		textureName = 0;
	}

	void bind() const {
		glBindTexture(GL_TEXTURE_2D, textureName);
	}
}