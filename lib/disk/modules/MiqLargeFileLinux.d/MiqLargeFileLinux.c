/*
 * Ruby module to read large files on Linux platforms.
 */

#define _LARGEFILE64_SOURCE

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

#include "ruby.h"

#define	CLOSED_FD	-1

static const char *class_name = "MiqLargeFileLinux";

/*
 * Called by GC when this object is free.
 * Close the file if it is open.
 */
static void
lf_free(void *p)	{
	if (*(int *)p == -1) return;
	close(*(int *)p);
	free(p);
}

/*
 * Private data allocation.
 *
 * We wrap the storage for the file descriptor so we can close
 * the file when GC frees this object.
 */
static VALUE
lf_alloc(VALUE klass)	{
	VALUE	obj;
	int	*fdp;

	/*
	 * Allocate instance-specific storage for the file descriptor.
	 */
	if ((fdp = malloc(sizeof(int))) == NULL)	{
		rb_raise(rb_eNoMemError,
			"%s::alloc - could not allocate memory for private data\n",
			class_name);
	}
	/*
	 * Wrap the fd storage and register a routine to free it.
	 */
	obj = Data_Wrap_Struct(klass, 0, lf_free, fdp);
	*fdp = CLOSED_FD;

	return obj;
}

/*
 * The "initialize" method.
 */
static VALUE
lf_init(VALUE self, VALUE fname, VALUE rflags)	{
	char	*fnp, *rffp;
	int	fd, *fdp, flags;

	/*
	 * Get the C-language representations of the Ruby
	 * objects passed in.
	 */
	fnp  = RSTRING_PTR(StringValue(fname));
	rffp = RSTRING_PTR(StringValue(rflags));

#	ifdef DEBUG
		printf("MiqLargeFileLinux[0x%lx] (new): file = %s, flags = %s\n", self, fnp, rffp);
#	endif

	/*
	 * Convert Ruby form of "open" flags to open(2) bit flags.
	 */
	flags = O_LARGEFILE;
	switch(*rffp)	{
		case 'r':
			if (*++rffp == '+') flags |= O_RDWR;	// Read/write: "r+"
			else flags |= O_RDONLY;					// Read-only:  "r"
			break;

		case 'w':
			flags |= O_CREAT | O_TRUNC;
			if (*++rffp == '+') flags |= O_RDWR;	// Read/write, trincate or create: "w+"
			else flags |= O_WRONLY;					// Write-only, truncate or create: "w"
			break;

		case 'a':
			flags |= O_CREAT | O_APPEND;
			if (*++rffp == '+') flags |= O_RDWR;	// Read/write, append or create: "a+"
			else flags |= O_WRONLY;					// Write-only, append or create: "a"
			break;

		case 'b':									// Binary mode, no-op on linux
			break;

		default:
			rb_raise(rb_eArgError,
				"%s::new on file: %s - unrecognized flag value: %c\n",
				class_name, fnp, *rffp);
	}

	/*
	 * Open the file.
	 */
	if ((fd = open(fnp, flags)) < 0)	{
		rb_raise(rb_eSystemCallError,
			"%s::new - open failed for file: %s, %s\n",
			class_name, fnp, strerror(errno));
	}

	/*
	 * Save the file name and file descriptor in instance variables.
	 */
	rb_iv_set(self, "@fileName", rb_str_new2(fnp));

	/*
	 * Set the file descriptor in private data space.
	 */
	Data_Get_Struct(self, int, fdp);
	*fdp = fd;

#	ifdef DEBUG
		printf("MiqLargeFileLinux[0x%lx] (init): fd = %d\n", self, *fdp);
#	endif
	
	return self;
}

/*
 * The "read" instance method.
 */
static VALUE
lf_read(VALUE self, VALUE bytes)	{
	VALUE rb;
	int  *fdp;
	char *buf;
	long len;
	int n = NUM2INT(bytes);		// the number of bytes to read

	/*
	 * Get the file descriptor from private data space.
	 */
	Data_Get_Struct(self, int, fdp);

#	ifdef DEBUG
		printf("MiqLargeFileLinux [0x%lx] (read): bytes = %d, fd = %d\n", self, n, *fdp);
#	endif

	/*
	 * Make sure we don't try to read a file we've closed.
	 */
	if (*fdp == CLOSED_FD)	{
		VALUE v = rb_iv_get(self, "@fileName");
#		ifdef DEBUG
			printf("MiqLargeFileLinux [0x%lx] (read): failed on file (fd = %d): %s, attempted read after close\n",
				self,
				*fdp,
				RSTRING_PTR(StringValue(v)));
#		endif
		rb_raise(rb_eSystemCallError,
			"%s::read - read failed on file: %s, attempted read after close\n",
			class_name,
			RSTRING_PTR(StringValue(v)));
	}

	/*
	 * Allocate a temp read buffer.
	 */
	if ((buf = malloc(n)) == NULL)	{
		VALUE v = rb_iv_get(self, "@fileName");
#		ifdef DEBUG
			printf("MiqLargeFileLinux [0x%lx] (read): on file (fd = %d): %s - could not allocate memory for read buffer\n",
				self,
				*fdp,
				RSTRING_PTR(StringValue(v)));
#		endif
		rb_raise(rb_eNoMemError,
			"%s::read on file: %s - could not allocate memory for read buffer\n",
			class_name,
			RSTRING_PTR(StringValue(v)));
	}

	/*
	 * Read data into the temp buffer.
	 */
	if ((len = read(*fdp, buf, n)) < 0)	{
		VALUE v = rb_iv_get(self, "@fileName");
#		ifdef DEBUG
			printf("MiqLargeFileLinux [0x%lx] (read): failed on file (fd = %d): %s, %s\n",
				self,
				*fdp,
				RSTRING_PTR(StringValue(v)),
				strerror(errno));
#		endif
		rb_raise(rb_eSystemCallError,
			"%s::read - read failed on file: %s, %s\n",
			class_name,
			RSTRING_PTR(StringValue(v)),
			strerror(errno));
	}

	/*
	 * Create a Ruby string and initialize it with the
	 * contents of the temp buffer.
	 */
	rb = rb_str_new(buf, len);
	// we no longer need the temp buffer.
	free(buf);
	// return the ruby string.
	return rb;
}

/*
 * The "write" instance method.
 */
static VALUE
lf_write(VALUE self, VALUE buf, VALUE bytes)	{
	int  *fdp;
	char *bufp;
	long len;
	int n = NUM2INT(bytes);		// the number of bytes to write

	/*
	 * Get the file descriptor from private data space.
	 */
	Data_Get_Struct(self, int, fdp);

#	ifdef DEBUG
		printf("MiqLargeFileLinux [0x%lx] (write): bytes = %d, fd = %d\n", self, n, *fdp);
#	endif

	/*
	 * Make sure we don't try to write a file we've closed.
	 */
	if (*fdp == CLOSED_FD)	{
		VALUE v = rb_iv_get(self, "@fileName");
#		ifdef DEBUG
			printf("MiqLargeFileLinux [0x%lx] (write): write failed on file (fd = %d): %s, attempted read after close\n",
				self,
				*fdp,
				RSTRING_PTR(StringValue(v)));
#		endif
		rb_raise(rb_eSystemCallError,
			"%s::write - write failed on file: %s, attempted read after close\n",
			class_name,
			RSTRING_PTR(StringValue(v)));
	}
	
	bufp = RSTRING_PTR(StringValue(buf));

	/*
	 * Write data to file.
	 */
	if ((len = write(*fdp, bufp, n)) < 0)	{
		VALUE v = rb_iv_get(self, "@fileName");
#		ifdef DEBUG
			printf("MiqLargeFileLinux [0x%lx] (write): write failed on file (fd = %d): %s, %s\n",
				self,
				*fdp,
				RSTRING_PTR(StringValue(v)),
				strerror(errno));
#		endif
		rb_raise(rb_eSystemCallError,
			"%s::write - write failed on file (fd = %d): %s, %s\n",
			class_name,
			*fdp,
			RSTRING_PTR(StringValue(v)),
			strerror(errno));
	}
	
	return INT2NUM(len);
}

/*
 * The "seek" instance method.
 */
static VALUE
lf_seek(VALUE self, VALUE offset, VALUE whence)	{
	int *fdp;
	long long o;

	/*
	 * Get the file descriptor from private data space.
	 */
	Data_Get_Struct(self, int, fdp);

	/*
	 * The offset value passed in is either a Fixnum or Bignum,
	 * convert accordingly.
	 */
	if (FIXNUM_P(offset))	{
		o = (long long)NUM2INT(offset);
	}
	else	{
		o = rb_big2ll(offset);
	}

#	ifdef DEBUG
		printf("MiqLargeFileLinux [0x%lx] (seek): offset = %lld, whence = %d, fd = %d\n",
			self, o, NUM2INT(whence), *fdp);
#	endif

	/*
	 * Make sure we don't try to seek on a file we've closed.
	 */
	if (*fdp == CLOSED_FD)	{
		VALUE v = rb_iv_get(self, "@fileName");
		rb_raise(rb_eSystemCallError,
			"%s::seek - seek failed on file: %s, attempted seek after close\n",
			class_name,
			RSTRING_PTR(StringValue(v)));
	}

	/*
	 * Perform seek operation on the file.
	 *
	 * This code assumes the values of the Ruby IO::SEEK_* constants
	 * and their corresponding C-library equivalents, are the same.
	 */
	if (lseek64(*fdp, o, NUM2INT(whence)) < 0)	{
		VALUE v = rb_iv_get(self, "@fileName");
		rb_raise(rb_eSystemCallError,
			"%s::seek - seek failed on file: %s, %s\n",
			class_name,
			RSTRING_PTR(StringValue(v)),
			strerror(errno));
	}

	return INT2NUM(0);
}

/*
 * The "size" instance method.
 */
static VALUE
lf_size(VALUE self)	{
	struct stat64	st;
	int *fdp;

	/*
	 * Get the file descriptor from private data space.
	 */
	Data_Get_Struct(self, int, fdp);

#	ifdef DEBUG
			printf("MiqLargeFileLinux [0x%lx] (size): fd = %d\n", self, *fdp);
#	endif

	if (*fdp == CLOSED_FD)	{
		VALUE v = rb_iv_get(self, "@fileName");
		rb_raise(rb_eSystemCallError,
			"%s::size - failed on file: %s, file is not open\n",
			class_name,
			RSTRING_PTR(StringValue(v)));
	}
	
	/*
	 * stat the file to get its size.
	 */
	if (fstat64(*fdp, &st) < 0)	{
		VALUE v = rb_iv_get(self, "@fileName");
		rb_raise(rb_eSystemCallError,
			"%s::size - stat failed on file: %s, %s\n",
			class_name,
			RSTRING_PTR(StringValue(v)),
			strerror(errno));
	}
	
	return OFFT2NUM(st.st_size);
}

/*
 * The "size" class method.
 */
static VALUE
lf_s_size(VALUE self, VALUE fname)	{
	char *fnp;
	struct stat64	st;
	
	/*
	 * Get the C-language representations of the Ruby
	 * objects passed in.
	 */
	fnp  = RSTRING_PTR(StringValue(fname));
	
#	ifdef DEBUG
			printf("MiqLargeFileLinux [0x%lx] (s_size): file = %s\n", self, *fnp);
#	endif
	
	/*
	 * stat the file to get its size.
	 */
	if (stat64(fnp, &st) < 0)	{
		rb_raise(rb_eSystemCallError,
			"%s::s_size - stat failed on file: %s, %s\n",
			class_name,
			fnp,
			strerror(errno));
	}
	
	return OFFT2NUM(st.st_size);
}

/*
 * The "close" instance method.
 */
static VALUE
lf_close(VALUE self)	{
	int *fdp;

	/*
	 * Get the file descriptor from private data space.
	 */
	Data_Get_Struct(self, int, fdp);

#	ifdef DEBUG
    do {
        VALUE v = rb_iv_get(self, "@fileName");
		printf("MiqLargeFileLinux [0x%lx] (close): fd = %d, File = %s\n", self, *fdp, RSTRING_PTR(StringValue(v)));
    } while(0);
#	endif

	if (*fdp != CLOSED_FD)	{
		close(*fdp);
		*fdp = CLOSED_FD;
	}
	return Qnil;
}

VALUE	cMiqLgFileLinux;

/*
 * Initialize the class.
 */
void Init_MiqLargeFileLinux()	{
	/*
	 * Define the class.
	 */
	cMiqLgFileLinux = rb_define_class(class_name, rb_cObject);

	/*
	 * Define method to allocate private data.
	 */
	rb_define_alloc_func(cMiqLgFileLinux, lf_alloc);

	/*
	 * Define the class' instance methods.
	 */
	rb_define_method(cMiqLgFileLinux, "initialize",	lf_init,  2);
	rb_define_method(cMiqLgFileLinux, "read",	lf_read,  1);
	rb_define_method(cMiqLgFileLinux, "write",	lf_write, 2);
	rb_define_method(cMiqLgFileLinux, "seek",	lf_seek,  2);
	rb_define_method(cMiqLgFileLinux, "size",	lf_size,  0);
	rb_define_method(cMiqLgFileLinux, "close",	lf_close, 0);
	
	/*
	 * Define class methods.
	 */
	rb_define_singleton_method(cMiqLgFileLinux, "size",	lf_s_size,  1);
}
