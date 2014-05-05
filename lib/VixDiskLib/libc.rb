require 'ffi'

class VixDiskLibLibC
  extend FFI::Library
  ffi_lib FFI::Library::LIBC

  attach_function :vsnprintf,   # http://www.cpluscplus.com/reference/cstdio/vsnprintf/
                  [
                    :buffer_in, # s
                    :int,	# n
                    :string,    # format
                    :pointer   # arg
                  ],
                  :int

  # memory allocators
  attach_function :malloc,  [:size_t],  :pointer
  attach_function :calloc,  [:size_t],  :pointer
  attach_function :valloc,  [:size_t],  :pointer
  attach_function :realloc, [:size_t],  :pointer
  attach_function :free,    [:pointer], :void

  attach_function :vprintf,
                  [
                    :string, # format
                    :pointer # va_list arg pointer
                  ],
                  :int

  # memory movers
  attach_function :memcpy, [:pointer, :pointer, :size_t], :pointer
  attach_function :bcopy,  [:pointer, :pointer, :size_t], :void
end
