
CC = c++

CFLAGS = -I/usr/local/lib/ruby/1.8/i686-darwin8.10.1
LDFLAGS = -static
LIBS = -lmk4 -lruby

mk4test: a.out
	rm -f mk4test
	cp a.out mk4test
	ruby MkSelectFiles.rb collect_files.yaml mk4test
	
a.out: mk4test.c
	$(CC) $(CFLAGS) $(LIBS) mk4test.c
