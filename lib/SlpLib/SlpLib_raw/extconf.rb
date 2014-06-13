require 'mkmf'

errs = false

if RUBY_PLATFORM =~ /mswin/
  $INCFLAGS << " -Iwin32 "
  $CFLAGS.sub! /-MD/, "-MT"
  if have_header("slp.h") && have_library("win32/slp")
     create_makefile("SlpLib_raw") 
  else
     puts "Can't build an extension, either you don't have a c++ compiler or metakit installed"
  end
else
    p $configure_args
	dir_config('slp')
    if !have_header("slp.h")
        puts "Could not find slp.h"
        errs = true
    end
    if !have_library("slp")
        puts "Could not find library: slp"
        errs = true
    end
    if !errs
		create_makefile("SlpLib_raw")
    else
        puts "Can't build an extension, required components not found"
    end
end
