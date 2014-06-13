/*
 * Ruby module to block device operations on Linux platforms.
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <linux/fs.h>
#include <malloc.h>

#include "ruby.h"

static const char *module_name = "MiqBlockDevOps";

static VALUE
blkgetsize64(VALUE self, VALUE rfd)	{
	int	fd;
	int64_t sz;
	
	fd = NUM2INT(rfd);
	
	if (ioctl(fd, BLKGETSIZE64, &sz) < 0)   {
		rb_raise(rb_eSystemCallError,
			"%s::blkgetsize64 - ioctl failed on file descriptor: %d, %s\n",
			module_name,
			fd,
			strerror(errno)
		);
	}
	return OFFT2NUM(sz);
}

static VALUE
aligned_str_buf(VALUE self, VALUE ralign, VALUE rlen) {
	size_t	align	= (size_t)NUM2INT(ralign);
	size_t	len		= (size_t)NUM2INT(rlen);
	char	*abuf;
	VALUE	asb;

	if ((abuf = memalign(align, len)) == NULL) {
		rb_raise(rb_eNoMemError, "Could not allocate %d bytes of aligned memory\n", len);
	}

	asb = rb_str_new(NULL, 0);
	RBASIC(asb)->flags |= RSTRING_NOEMBED;
	RSTRING(asb)->as.heap.ptr = abuf;
	RSTRING(asb)->as.heap.aux.capa = len;

	return(asb);
}

VALUE	mMiqBlockDevOps;

/*
 * Initialize the class.
 */
void Init_MiqBlockDevOps()	{
	/*
	 * Define the module.
	 */
	mMiqBlockDevOps = rb_define_module(module_name);

	rb_define_singleton_method(mMiqBlockDevOps, "blkgetsize64",	blkgetsize64,  1);
	rb_define_singleton_method(mMiqBlockDevOps, "aligned_str_buf",	aligned_str_buf,  2);
}
