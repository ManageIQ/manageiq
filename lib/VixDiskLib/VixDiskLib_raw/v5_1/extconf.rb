require 'mkmf'

errs = false
windows = ($mswin || $mingw)

if windows
  $configure_args['--with-vixDiskLib-dir'] = 'C:\\Program Files (x86)\\VMware\\VMware Virtual Disk Development Kit'
else
  $configure_args['--with-vixDiskLib-include'] = '/usr/lib/vmware-vix-disklib/include'
  $configure_args['--with-vixDiskLib-lib'] = '/usr/lib/vmware-vix-disklib/lib64'
end

# pass args to configure
ARGV.each_slice(2) {|option, value| $configure_args[option] = value}

dir_config('vixDiskLib')
p $configure_args

if windows
  $objs = %w{VixDiskLib_raw.5.1.def VixDiskLib_raw.5.1.o}
  $DLDFLAGS = $DLDFLAGS.split(',').delete_if {|f| f == "--export-all"}.join(',')
end

if !have_header("vixDiskLib.h")
  puts "Could not find vixDiskLib.h"
  errs = true
end

if !have_library("vixDiskLib")
  puts "Could not find library: vixDiskLib"
  errs = true
end

if !have_library("ssl")
  unless windows
    puts "Could not find library: ssl"
    errs = true
  end
else
  have_header("openssl/evp.h")
end

if !errs
  create_makefile("VixDiskLib_raw.5.1")
else
  puts "Can't build an extension, required components not found"
end
