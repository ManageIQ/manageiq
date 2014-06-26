require 'ffi'

module FFI
  module VixDiskLib
    module API
      extend FFI::Library
      ffi_lib FFI::Library::LIBC

      attach_function :vsnprintf,   # http://www.cpluscplus.com/reference/cstdio/vsnprintf/
                      [
                        :buffer_in, # s
                        :int,	    # n
                        :string,    # format
                        :pointer,   # arg
                      ],
                      :int
    end
  end
end
