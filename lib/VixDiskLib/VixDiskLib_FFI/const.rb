require 'ffi'

module FFI
  module VixDiskLib
    module API
      extend FFI::Library

      # An error is a 64-bit value. If there is no error, then the value is
      # set to VIX_OK. If there is an error, then the least significant bits
      # will be set to one of the integer error codes defined below. The more
      # significant bits may or may not be set to various values, depending on
      # the errors.

      typedef :uint64, :VixError

      typedef :uint64,  :SectorType
      typedef :pointer, :Connection

      VIXDISKLIB_SECTOR_SIZE = 512

      # Virtual hardware version

      # VMware Workstation 4.x and GSX Server 3.x
      HWVERSION_WORKSTATION_4 = 3

      # VMware Workstation 5.x and Server 1.x
      HWVERSION_WORKSTATION_5 = 4

      # VMware ESX Server 3.0
      HWVERSION_ESX30 = HWVERSION_WORKSTATION_5

      # VMware Workstation 6.x
      HWVERSION_WORKSTATION_6 = 6

      # Defines the state of the art hardware version. Be careful using this as it
      # will change from time to time.
      HWVERSION_CURRENT = HWVERSION_WORKSTATION_6

      # Flags for open
      VIXDISKLIB_FLAG_OPEN_UNBUFFERED = (1 << 0)  # disable host disk caching
      VIXDISKLIB_FLAG_OPEN_SINGLE_LINK = (1 << 1) # don't open parent disk(s)
      VIXDISKLIB_FLAG_OPEN_READ_ONLY = (1 << 2)   # open read-only
    end
  end
end
