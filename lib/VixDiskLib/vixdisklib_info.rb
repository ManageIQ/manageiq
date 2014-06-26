require 'vixdisklib_api'
#
# Initialize a hash with the disk info for the specified handle
# using the VixDiskLib_GetInfo method.
# This is a helper class for the VixDiskLibApi::get_info method.
#
class DiskInfo < VixDiskLibApi
  VixDiskLib = FFI::VixDiskLib::API
  extend VixDiskLib
  attr_reader :info
  def initialize(disk_handle)
    ruby_info = {}
    info = FFI::MemoryPointer.new :pointer
    vix_error = VixDiskLib.getinfo(disk_handle, info)
    self.class.check_error(vix_error, __method__)
    real_info = info.get_pointer(0)

    ruby_info[:biosGeo]             = {}
    ruby_info[:physGeo]             = {}
    bios_offset = VixDiskLib::Info.offset_of(:biosGeo)
    phys_offset = VixDiskLib::Info.offset_of(:biosGeo)
    ruby_info[:biosGeo][:cylinders] = real_info.get_uint32(bios_offset + VixDiskLib::Geometry.offset_of(:cylinders))
    ruby_info[:biosGeo][:heads]     = real_info.get_uint32(bios_offset + VixDiskLib::Geometry.offset_of(:heads))
    ruby_info[:biosGeo][:sectors]   = real_info.get_uint32(bios_offset + VixDiskLib::Geometry.offset_of(:sectors))
    ruby_info[:physGeo][:cylinders] = real_info.get_uint32(phys_offset + VixDiskLib::Geometry.offset_of(:cylinders))
    ruby_info[:physGeo][:heads]     = real_info.get_uint32(phys_offset + VixDiskLib::Geometry.offset_of(:heads))
    ruby_info[:physGeo][:sectors]   = real_info.get_uint32(phys_offset + VixDiskLib::Geometry.offset_of(:sectors))
    ruby_info[:capacity]            = real_info.get_uint64(VixDiskLib::Info.offset_of(:capacity))
    ruby_info[:adapterType]         = real_info.get_int(VixDiskLib::Info.offset_of(:adapterType))
    ruby_info[:numLinks]            = real_info.get_int(VixDiskLib::Info.offset_of(:numLinks))

    parent_info = real_info + VixDiskLib::Info.offset_of(:parentFileNameHint)
    parent_info_str = parent_info.read_pointer
    ruby_info[:parentFileNameHint]  = parent_info_str.read_string unless parent_info_str.null?
    uuid_info_str = (real_info + VixDiskLib::Info.offset_of(:uuid)).read_pointer
    ruby_info[:uuid]                = uuid_info_str.read_string unless uuid_info_str.null?
    # VixDiskLib.freeinfo(real_info)
    @info = ruby_info
  end
end # class DiskInfo
