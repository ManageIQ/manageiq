require 'vixdisklib_api'

class SafeCreateParams < VixDiskLibApi
  extend FFI::VixDiskLib::API
  #
  # Read the contents of a CreateParams structure passed as an argument
  # into FFI memory which will be allocated to be used when calling out to
  # VixDiskLib
  #
  attr_reader :create_params
  def initialize(in_create_parms)
    create_parms = FFI::MemoryPointer.new(VixDiskLib::CreateParams, 1, true)
    create_parms_start = create_parms
    disk_type = in_create_parms[:diskType]
    create_parms = create_parms_start + VixDiskLib::CreateParams.offset_of(:diskType)
    create_parms.write_int(DiskType[disk_type]) unless in_create_parms[:diskType].nil?
    adapter_type = in_create_parms[:adapterType]
    create_parms = create_parms_start + VixDiskLib::CreateParams.offset_of(:adapterType)
    create_parms.write_int(AdapterType[adapter_type]) unless in_create_parms[:adapterType].nil?
    create_parms = create_parms_start + VixDiskLib::CreateParams.offset_of(:hwVersion)
    create_parms.write_uint16(in_create_parms[:hwVersion]) unless in_create_parms[:hwVersion].nil?
    create_parms = create_parms_start + VixDiskLib::CreateParams.offset_of(:capacity)
    create_parms.write_uint64(in_create_parms[:capacity]) unless in_create_parms[:capacity].nil?
    @create_params = create_parms_start
  end
end # class SafeCreateParams
