
#
# Temporary Test to enable comparison testing between the
# new FFI/DRB binding to VixDisklib currently found in 'VixDiskLibClient.rb'
# and the old C binding to VixDisklib currently found in 'VixDiskLibRawC.rb'
# once testing is done this file will be removed, and the file
# 'VixDiskLibClient.rb' will be renamed 'VixdiskLib.rb'
#
# To test The C Binding, set the environment variable VIXDISKLIB_BINDING to "C"
# and either run a standalone test, or restart the appliance via "rake evm:restart".
#
# To test the FFI Binding, either unset the VIXDISKLIB_BINDING environment variable
# or set it to "FFI".  Run the tests or appliance restart the same way.
#
class VixDiskLibError < RuntimeError
end

vixdisklib_binding = ENV['VIXDISKLIB_BINDING'] || "FFI"
if vixdisklib_binding.downcase == "c"
  require 'VixDiskLibRawC'
elsif vixdisklib_binding.downcase == "ffi"
  require 'VixDiskLibClient'
else
  raise VixDiskLibError, "VixDiskLib() failed: Invalid VIXDISKLIB_BINDING Environment variable #{vixdisklib_binding}"
end
