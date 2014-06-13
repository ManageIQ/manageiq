require 'mkmf'

errs = false
windows = ($mswin || $mingw)
sdk_base = File.join(File.dirname(__FILE__), "../../../../../netapp-manageability-sdk/netapp-manageability-sdk-4.0P1")

$configure_args['--with-netappManageabilitySdk-include'] = "/usr/include/netapp"

if windows
	$configure_args['--with-netappManageabilitySdk-lib'] = File.join(sdk_base, "lib/nt")
 	libs = [ "ws2_32", "libadt", "libxml", "libeay32", "ssleay32", "odbc32", "odbccp32", "libnetapp" ]
	$LDFLAGS = "-static"
	# $DLDFLAGS = $DLDFLAGS.split(',').delete_if {|f| f == "--export-all"}.join(',')
else
	$configure_args['--with-netappManageabilitySdk-lib'] = "/usr/lib64/netapp"
	libs = [ "z", "xml", "pthread", "nsl", "m", "crypto", "ssl", "dl", "rt", "adt", "netapp" ]
end

dir_config('netappManageabilitySdk')

if !have_header("netapp_api.h")
	puts "Could not find netapp_api.h"
	errs = true
end

libs.each do |lib|
	if !have_library(lib)
		puts "Could not find library: #{lib}"
		errs = true
	end
end

if !errs
	create_makefile("NmaCore_raw")
else
	puts "Can't build an extension, required components not found"
end
