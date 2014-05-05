require_relative './libc'
require 'vixdisklib_ffi'

class VixDiskLibError < RuntimeError
end

class VixDiskLibApi < VixDiskLibFFI
  attr_reader :info_logger, :warn_logger, :error_logger

  def self.attach(parent_disk_handle, child_disk_handle)
    vix_error = super(parent_disk_handle, child_disk_handle)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_CheckRepair method
  #
  def self.check_repair(connection, file_name, repair)
    file_ptr = FFI::MemoryPointer.from_string(file_name)
    vix_error = super(connection, file_ptr, repair)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Cleanup method
  #
  def self.cleanup(connect_parms)
    safe_parms = SafeConnectParams.new(connect_parms)
    cleaned_up = FFI::MemoryPointer.new :pointer
    remaining = FFI::MemoryPointer.new :pointer
    vix_error = super(safe_parms.connect_params, cleaned_up, remaining)
    safe_parms.free_parms
    num_cleaned_up = cleaned_up.get_uint32(0) unless cleaned_up.nil?
    num_remaining = remaining.get_uint32(0) unless remaining.nil?
    check_error(vix_error, __method__)
    return num_cleaned_up, num_remaining
  end

  #
  # The VixDiskLib_Clone method
  #
  def self.clone(dest_connection, dest_path, src_connection, src_path, create_parms, over_write)
    dest_ptr = FFI::MemoryPointer.from_string(dest_path)
    src_ptr = FFI::MemoryPointer.from_string(src_path)
    safe_parms = SafeCreateParams.new(create_parms)
    vix_error = super(dest_connection, dest_ptr, src_connection, src_ptr,
                      safe_parms.create_params, nil, nil, over_write)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Close method
  #
  def self.close(disk_handle)
    vix_error = super(disk_handle)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Connect method
  #
  def self.connect(connect_parms)
    connection = FFI::MemoryPointer.new :pointer
    safe_parms = SafeConnectParams.new(connect_parms)
    vix_error = super(safe_parms.connect_params, connection)
    connection = connection.get_pointer(0)
    safe_parms.free_parms
    check_error(vix_error, __method__)
    connection
    rescue Exception => err
      puts "Exception in connect: #{err.to_s}"
      puts err.class.name
      puts err.backtrace.join("\n")
  end

  #
  # The VixDiskLib_ConnectEx method
  #
  def self.connect_ex(connect_parms, read_only, snapshot_ref, transport_modes)
    connection = FFI::MemoryPointer.new :pointer
    safe_parms = SafeConnectParams.new(connect_parms)
    snapshot_ptr = snapshot_ref.nil? ? nil : FFI::MemoryPointer.from_string(snapshot_ref)
    modes_ptr = transport_modes.nil? ? nil : FFI::MemoryPointer.from_string(transport_modes)
    vix_error = super(safe_parms.connect_params, read_only, snapshot_ptr, modes_ptr, connection)
    connection = connection.get_pointer(0)
    safe_parms.free_parms
    check_error(vix_error, __method__)
    connection
  end

  #
  # The VixDiskLib_Create method
  #
  def self.create(connection, path, create_parms, prog_func = nil, prog_callback_data = nil)
    safe_parms = SafeCreateParams.new(create_parms)
    path_ptr = FFI::MemoryPointer.from_string(path)
    vix_error = super(connection, path_ptr, safe_parms.create_params, prog_func, prog_callback_data)
    safe_parms.free_parms
    check_error(vix_error, __method)
    nil
  end

  #
  # The VixDiskLib_CreateChild method
  #
  def self.create_child(disk_handle, child_path, disk_type, prog_func = nil, prog_callback_data = nil)
    path_ptr = FFI::MemoryPointer.from_string(child_path)
    vix_error = super(disk_handle, path_ptr, disk_type, prog_func, prog_callback_data)
    check_error(vix_error, __method)
    nil
  end

  #
  # The VixDiskLib_Defragment method
  #
  def self.defragment(disk_handle)
    vix_error = super(disk_handle, nil, nil)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Disconnect method
  #
  def self.disconnect(connection)
    vix_error = super(connection)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Access method
  #
  def self.end_access(connect_parms, identity)
    safe_parms = SafeConnectParams.new(connect_parms)
    identity_ptr = FFI::MemoryPointer.from_string(identity)
    vix_error = super(safe_parms.connect_params, identity_ptr)
    safe_parms.free_parms
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Exit method
  #
  def self.exit
    super
    nil
  end

  #
  # The VixDiskLib_FreeConnectParams method
  #
  def self.free_connect_params(connect_params)
    super(connect_params)
  end

  #
  # The VixDiskLib_GetConnectParams method
  #
  def self.get_connect_params(connection)
    params_ptr = FFI::MemoryPointer.new :pointer
    vix_error = super(connection, params_ptr)
    check_error(vix_error, __method__)
    ffi_connect_params = params_ptr.get_pointer(0)
    safe_connect_params = SafeConnectParams.read(ffi_connect_params)
    free_connect_params(ffi_connect_params)
    safe_connect_params
  end

  #
  # The VixDiskLib_GetInfo method
  #
  def self.get_info(disk_handle)
    info = DiskInfo.new(disk_handle)
    info.info
  end

  #
  # The VixDiskLib_GetMetadataKeys method
  #
  def self.get_metadata_keys(disk_handle)
    #
    # Get the size of the buffer required for the metadata keys for the disk.
    #
    len_ptr = FFI::MemoryPointer.new :pointer
    vix_error = super(disk_handle, nil, 0, len_ptr)
    if vix_error != VixErrorType[:VIX_OK] && vix_error != VixErrorType[:VIX_E_BUFFER_TOOSMALL]
      check_error(vix_error, __method__)
    end
    #
    # Read the metadata keys for the disk into the allocated buffer.
    #
    buf_size = len_ptr.get_uint64(0)
    read_buf = FFI::MemoryPointer.new(buf_size)
    vix_error = super(disk_handle, read_buf, buf_size, nil)
    check_error(vix_error, __method__)
    keys = read_buf.get_bytes(0, buf_size)
    keys.split("\x00")
  end

  #
  # The VixDiskLib_GetTransportMode method
  #
  def self.get_transport_mode(disk_handle)
    mode = super(disk_handle)
    mode.read_string
  end

  #
  # The VixDiskLib_Grow method
  #
  def self.grow(connection, path, capacity, update_geometry)
    path_ptr = FFI::MemoryPointer.from_string(path)
    vix_error = super(connection, path_ptr, capacity, update_geometry, nil, nil)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Init method
  #
  def self.init(info_logger = nil, warn_logger = nil, error_logger = nil, libDir = nil)
    @info_logger, @warn_logger, @error_logger = info_logger, warn_logger, error_logger

    vix_error = super(VERSION_MAJOR, VERSION_MINOR, logger_for("info"), logger_for("warn"), logger_for("error"), libDir)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_InitEx method
  #
  def self.init_ex(info_logger = nil, warn_logger = nil, error_logger = nil, libDir = nil, configFile = nil)
    @info_logger, @warn_logger, @error_logger = info_logger, warn_logger, error_logger

    vix_error = super(VERSION_MAJOR, VERSION_MINOR,
                      logger_for("info"), logger_for("warn"), logger_for("error"), libDir, configFile)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_IsAttachPossible method
  #
  def self.is_attach_possible(parent_disk_handle, child_disk_handle)
    vix_error = super(parent_disk_handle, child_disk_handle)
    VIX_SUCCEEDED(vix_error)
  end

  #
  # The VixDiskLib_ListTransportModes method
  #
  def self.list_transport_modes
    list = super
    list.read_string
  end

  #
  # The VixDiskLib_Open method
  #
  def self.open(connection, path, flags)
    path_ptr = FFI::MemoryPointer.from_string(path)
    disk_handle = FFI::MemoryPointer.new :pointer
    vix_error = super(connection, path_ptr, flags, disk_handle)
    check_error(vix_error, __method__)
    disk_handle.get_pointer(0)
  end

  #
  # The VixDiskLib_PrepareForAccess method
  #
  def self.prepare_for_access(connect_parms, identity)
    safe_parms = SafeConnectParams.new(connect_parms)
    identity_ptr = FFI::MemoryPointer.from_string(identity)
    vix_error = super(safe_parms.connect_params, identity_ptr)
    safe_parms.free_parms
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Read method
  #
  def self.read(disk_handle, start_sector, num_sectors)
    buf_size = num_sectors * VixDiskLibFFI::VIXDISKLIB_SECTOR_SIZE
    read_buf = FFI::MemoryPointer.new(buf_size)
    read_buf.clear
    vix_error = super(disk_handle, start_sector, num_sectors, read_buf)
    check_error(vix_error, __method__)
    read_buf.get_bytes(0, buf_size)
  end

  #
  # The VixDiskLib_ReadMetadata method
  #
  def self.read_metadata(disk_handle, key)
    key_ptr = FFI::MemoryPointer.from_string(key)
    #
    # Get the size of the buffer required for the metadata key for this disk.
    #
    len_ptr = FFI::MemoryPointer.new :pointer
    vix_error = super(disk_handle, key_ptr, nil, 0, len_ptr)
    if vix_error != VixErrorType[:VIX_OK] && vix_error != VixErrorType[:VIX_E_BUFFER_TOOSMALL]
      check_error(vix_error, __method__)
    end
    #
    # Read the metadata key for the disk into the allocated buffer.
    #
    buf_size = len_ptr.get_uint64(0)
    read_buf = FFI::MemoryPointer.new(buf_size)
    vix_error = super(disk_handle, key_ptr, read_buf, buf_size, nil)
    check_error(vix_error, __method__)
    read_buf.get_bytes(0, buf_size)
  end

  #
  # The VixDiskLib_Rename method
  #
  def self.rename(src_path, dest_path)
    src_ptr = FFI::MemoryPointer.from_string(src_path)
    dest_ptr = FFI::MemoryPointer.from_string(dest_path)
    vix_error = super(src_ptr, dest_ptr)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Shrink method
  #
  def self.shrink(disk_handle, prog_func = nil, prog_callback_data = nil)
    vix_error = super(disk_handle, prog_func, prog_callback_data)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_SpaceNeededForClone method
  #
  def self.space_needed_for_clone(disk_handle, disk_type)
    needed_ptr = FFI::MemoryPointer.new :pointer
    vix_error = super(disk_handle, disk_type, needed_ptr)
    check_error(vix_error, __method__)
    needed_ptr.get_uint64(0)
  end

  #
  # The VixDiskLib_Unlink method
  #
  def self.unlink(connection, path)
    path_ptr = FFI::MemoryPointer.from_string(path)
    vix_error = super(connection, path_ptr)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Write method
  #
  def self.write(disk_handle, start_sector, num_sectors, buf)
    buf_size = num_sectors * :VIXDISKLIB_SECTOR_SIZE
    buf_ptr = FFI::MemoryPointer.new(buf_size)
    buf_ptr.write_bytes(buf, 0, buf_size)
    vix_error = super(disk_handle, start_sector, num_sectors, buf_ptr)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_WriteMetadata method
  #
  def self.write_metadata(disk_handle, key, value)
    key_ptr = FFI::MemoryPointer.from_string(key)
    val_ptr = FFI::MemoryPointer.from_string(value)
    vix_error = super(disk_handle, key_ptr, val_ptr)
    check_error(vix_error, __method__)
    nil
  end

  private

  INFO_LOGGER = proc do |fmt, args|
    # @info_logger.call(process_log_args(fmt, args)) unless @info_logger.nil?
    process_log_args(fmt, args)
  end

  WARN_LOGGER = proc do |fmt, args|
    # @warn_logger.call(process_log_args(fmt, args)) unless @warn_logger.nil?
    process_log_args(fmt, args)
  end

  ERROR_LOGGER = proc do |fmt, args|
    # @error_logger.call(process_log_args(fmt, args)) unless @error_logger.nil?
    process_log_args(fmt, args)
  end

  def self.logger_for(level)
    instance_variable_get("@#{level.downcase}_logger") && const_get("#{level.upcase}_LOGGER")
  end

  def self.process_log_args(fmt, args)
    buf = FFI::MemoryPointer.new(:char, 1024, true)
    VixDiskLibLibC.vsnprintf(buf, 1024, fmt, args)
    real_buf = buf.read_string
    puts real_buf
    real_buf
  end

  def self.check_error(err, method)
    if VIX_FAILED(err)
      err_msg = getErrorText(err, nil)
      err_code = VIX_ERROR_CODE(err)
      err_name = VixErrorType[err_code]
      if err_msg.nil? || err_msg.null?
        err_msg = "Error retrieving text of error message for errcode."
        msg = "#{name}##{method} (errcode=#{err_code} - #{err_name}): #{err_msg}"
      else
        msg = "#{name}##{method} (errcode=#{err_code} - #{err_name}): #{err_msg.read_string}"
        freeErrorText(err_msg)
      end
      raise VixDiskLibError, "#{msg}"
    end
  end
end

class SafeConnectParams < VixDiskLibFFI
  #
  # Read the contents of a ConnectParams structure
  # into FFI memory for use when calling out to VixDiskLib
  #
  attr_reader :connect_params
  def initialize(in_connect_parms)
    conn_parms = FFI::MemoryPointer.new(ConnectParams, 1, true)
    conn_parms_start = conn_parms
    conn_parms = conn_parms_start + ConnectParams.offset_of(:vmxSpec)
    # Structure pointer (conn_parms) starts with vmxSpec
    write_safe_str_2_mem(in_connect_parms[:vmxSpec], conn_parms)
    # Increment structure pointer to server_name
    conn_parms = conn_parms_start + ConnectParams.offset_of(:serverName)
    write_safe_str_2_mem(in_connect_parms[:serverName], conn_parms)
    # Increment structure pointer to thumbPrint
    conn_parms = conn_parms_start + ConnectParams.offset_of(:thumbPrint)
    write_safe_str_2_mem(in_connect_parms[:thumbPrint], conn_parms)
    # Increment structure pointer to privateUse
    conn_parms = conn_parms_start + ConnectParams.offset_of(:privateUse)
    conn_parms.write_long(in_connect_parms[:privateUse]) unless in_connect_parms[:privateUse].nil?
    # Increment structure pointer to credType
    cred_type = in_connect_parms[:credType]
    conn_parms = conn_parms_start + ConnectParams.offset_of(:credType)
    conn_parms.write_int(CredType[cred_type]) unless in_connect_parms[:credType].nil?
    get_safe_creds(cred_type, in_connect_parms, conn_parms_start + ConnectParams.offset_of(:creds))
    conn_parms = conn_parms_start + ConnectParams.offset_of(:port)
    conn_parms.write_uint32(in_connect_parms[:port]) unless in_connect_parms[:port].nil?
    @connect_params = conn_parms_start
  end

  #
  # Read a ConnectParams structure returned from the FFI layer from VixDiskLib_GetConnectParams
  # into a ruby hash.
  #
  def self.read(ffi_connect_parms)
    out_connect_parms = {}
    spec_ptr = ffi_connect_parms.get_pointer(ConnectParams.offset_of(:vmxSpec))
    out_connect_parms[:vmxSpec] = spec_ptr.read_string unless spec_ptr.null?
    serv_ptr = ffi_connect_parms.get_pointer(ConnectParams.offset_of(:serverName))
    out_connect_parms[:serverName] = serv_ptr.read_string unless serv_ptr.null?
    thumb_ptr = ffi_connect_parms.get_pointer(ConnectParams.offset_of(:thumbPrint))
    out_connect_parms[:thumbPrint] = thumb_ptr.read_string unless thumb_ptr.null?
    out_connect_parms[:privateUse] = ffi_connect_parms.get_long(ConnectParams.offset_of(:privateUse))
    out_connect_parms[:credType] = ffi_connect_parms.get_long(ConnectParams.offset_of(:credType))
    cred_type = out_connect_parms[:credType]
    read_creds(cred_type, out_connect_parms, ffi_connect_parms + ConnectParams.offset_of(:creds))
    out_connect_parms
  end

  #
  # Read a ConnectParams Creds sub-structure returned from the FFI layer from VixDiskLib_GetConnectParams
  # into a ruby hash.
  #
  def self.read_creds(cred_type, conn_parms, ffi_creds)
    if cred_type == CredType[:VIXDISKLIB_CRED_UID]
      user_ptr = ffi_creds + Creds.offset_of(:uid) + UidPasswdCreds.offset_of(:userName)
      conn_parms[:userName] = read_safe_str_from_mem(user_ptr)
      pass_ptr = ffi_creds + Creds.offset_of(:uid) + UidPasswdCreds.offset_of(:password)
      conn_parms[:password] = read_safe_str_from_mem(pass_ptr)
    elsif cred_type == CredType[:VIXDISKLIB_CRED_SESSIONID]
      cookie_ptr = ffi_creds + Creds.offset_of(:sessionId) + UidPasswdCreds.offset_of(:cookie)
      conn_parms[:cookie] = read_safe_str_from_mem(cookie_ptr)
      user_ptr = ffi_creds + Creds.offset_of(:sessionId) + UidPasswdCreds.offset_of(:sessionUserName)
      conn_parms[:sessionUserName] = read_safe_str_from_mem(user_ptr)
      key_ptr = ffi_creds + Creds.offset_of(:sessionId) + UidPasswdCreds.offset_of(:key)
      conn_parms[:key] = read_safe_str_from_mem(key_ptr)
    elsif cred_type == CredType[:VIXDISKLIB_CRED_TICKETID]
      dummy_ptr = ffi_creds + Creds.offset_of(:ticketId) + UidPasswdCreds.offset_of(:dummy)
      conn_parms[:dummy] = read_safe_str_from_mem(dummy_ptr)
    end
  end

  #
  # Free the contents of a ConnectParams structure previously allocated
  # via the initialize method.
  #
  def free_parms
    conn_parms = @connect_params + ConnectParams.offset_of(:vmxSpec)
    free_safe_str(conn_parms)
    conn_parms = @connect_params + ConnectParams.offset_of(:serverName)
    free_safe_str(conn_parms)
    conn_parms = @connect_params + ConnectParams.offset_of(:thumbPrint)
    cred_type = conn_parms.read_int
    free_safe_str(conn_parms)
    free_creds(cred_type, @connect_params + ConnectParams.offset_of(:creds))
    # Now get rid of the structure itself
    @connect_params.free
    @connect_params = nil
  end

  #
  # Free the contents of the ConnectParams Creds sub-structure.
  #
  def free_creds(cred_type, cred_ptr)
    if cred_type == CredType[:VIXDISKLIB_CRED_UID]
      conn_parms = cred_ptr + Creds.offset_of(:uid) + UidPasswdCreds.offset_of(:userName)
      free_safe_str(conn_parms)
      conn_parms = cred_ptr + Creds.offset_of(:uid) + UidPasswdCreds.offset_of(:password)
      free_safe_str(conn_parms)
    elsif cred_type == CredType[:VIXDISKLIB_CRED_SESSIONID]
      conn_parms = cred_ptr + Creds.offset_of(:sessionId) + SessionIdCreds.offset_of(:cookie)
      free_safe_str(conn_parms)
      conn_parms = cred_ptr + Creds.offset_of(:sessionId) + SessionIdCreds.offset_of(:sessionUserName)
      free_safe_str(conn_parms)
      conn_parms = cred_ptr + Creds.offset_of(:sessionId) + SessionIdCreds.offset_of(:key)
      free_safe_str(conn_parms)
    end
  end

  private

  def self.read_safe_str_from_mem(mem_ptr)
    mem_str = mem_ptr.read_pointer
    mem_str.read_string unless mem_str.null?
  end

  def get_safe_creds(cred_type, in_creds, out_cred_ptr)
    if cred_type == :VIXDISKLIB_CRED_UID
      # Increment structure pointer to creds field's username
      # This should take care of any padding necessary for the Union.
      conn_parms = out_cred_ptr + Creds.offset_of(:uid) + UidPasswdCreds.offset_of(:userName)
      write_safe_str_2_mem(in_creds[:userName], conn_parms)
      # Increment structure pointer to creds field's password
      conn_parms = out_cred_ptr + Creds.offset_of(:uid) + UidPasswdCreds.offset_of(:password)
      write_safe_str_2_mem(in_creds[:password], conn_parms)
    elsif cred_type == :VIXDISKLIB_CRED_SESSIONID
      conn_parms = out_cred_ptr + Creds.offset_of(:sessionId) + SessionIdCreds.offset_of(:cookie)
      write_safe_str_2_mem(in_creds[:cookie], conn_parms)
      conn_parms = out_cred_ptr + Creds.offset_of(:sessionId) + SessionIdCreds.offset_of(:sessionUserName)
      write_safe_str_2_mem(in_creds[:sessionUserName], conn_parms)
      conn_parms = out_cred_ptr + Creds.offset_of(:sessionId) + SessionIdCreds.offset_of(:key)
      write_safe_str_2_mem(in_creds[:key], conn_parms)
    elsif cred_type == :VIXDISKLIB_CRED_TICKETID
      conn_parms = out_cred_ptr + Creds.offset_of(:ticketId) + SessionIdCreds.offset_of(:dummy)
      write_safe_str_2_mem(in_creds[:dummy], conn_parms)
    elsif cred_type == :VIXDISKLIB_CRED_SSPI
      puts "VixDiskLibApi.connect - Connection Parameters Credentials Type SSPI"
    elsif cred_type == :VIXDISKLIB_CRED_UNKNOWN
      puts "VixDiskLibApi.connect - unknown Connection Parameters Credentials Type"
    end
  end
  #
  # Allocate a new pointer in memory.
  # Copy the input string to that new pointer.
  # Write the pointer to the string to the allocated structure location.
  # If the string is nil write the empty string.
  #
  def write_safe_str_2_mem(input, mem_ptr)
    # tmp_ptr = FFI::MemoryPointer.new :pointer
    if input.nil?
      tmp_ptr = nil
    else
      tmp_ptr = VixDiskLibLibC.calloc(input.size + 1)
      tmp_ptr.write_string(input, input.size)
    end
    mem_ptr.put_pointer(0, tmp_ptr)
  end
  #
  # Free a string in memory previously allocated via write_safe_str_2_mem
  #
  def free_safe_str(mem_ptr)
    return if mem_ptr.nil?
    str_ptr = mem_ptr.get_pointer(0)
    VixDiskLibLibC.free(str_ptr) unless str_ptr.null?
  end
end

class SafeCreateParams < VixDiskLibFFI
  #
  # Read the contents of a CreateParams structure passed as an argument
  # into FFI memory which will be allocated to be used when calling out to
  # VixDiskLib
  #
  attr_reader :create_params
  def initialize(in_create_parms)
    create_parms = FFI::MemoryPointer.new(CreateParams, 1, true)
    create_parms_start = create_parms
    disk_type = in_create_parms[:diskType]
    create_parms = create_parms_start + CreateParams.offset_of(:diskType)
    create_parms.write_int(DiskType[disk_type]) unless in_create_parms[:diskType].nil?
    adapter_type = in_create_parms[:adapterType]
    create_parms = create_parms_start + CreateParams.offset_of(:adapterType)
    create_parms.write_int(AdapterType[adapter_type]) unless in_create_parms[:adapterType].nil?
    create_parms = create_parms_start + CreateParams.offset_of(:hwVersion)
    create_parms.write_uint16(in_create_parms[:hwVersion]) unless in_create_parms[:hwVersion].nil?
    create_parms = create_parms_start + CreateParams.offset_of(:capacity)
    create_parms.write_uint64(in_create_parms[:capacity]) unless in_create_parms[:capacity].nil?
    @create_params = create_parms_start
  end
  #
  # Free the contents of a CreateParams structure previously allocated
  # via the initialize method.
  #
  def free_parms
    @create_params.free
    @create_params = nil
  end
end

#
# Initialize a hash with the disk info for the specified handle
# using the VixDiskLib_GetInfo method.
# This is a helper class for the VixDiskLibApi::get_info method.
#
class DiskInfo < VixDiskLibApi
  attr_reader :info
  def initialize(disk_handle)
    ruby_info = {}
    info = FFI::MemoryPointer.new :pointer
    vix_error = getinfo(disk_handle, info)
    self.class.check_error(vix_error, __method__)
    real_info = info.get_pointer(0)
    # num_sectors = sector_ptr.read_uint64
    ruby_info[:biosGeo]             = {}
    ruby_info[:physGeo]             = {}
    ruby_info[:biosGeo][:cylinders] = real_info.get_uint32(Info.offset_of(:biosGeo) + Geometry.offset_of(:cylinders))
    ruby_info[:biosGeo][:heads]     = real_info.get_uint32(Info.offset_of(:biosGeo) + Geometry.offset_of(:heads))
    ruby_info[:biosGeo][:sectors]   = real_info.get_uint32(Info.offset_of(:biosGeo) + Geometry.offset_of(:sectors))
    ruby_info[:physGeo][:cylinders] = real_info.get_uint32(Info.offset_of(:physGeo) + Geometry.offset_of(:cylinders))
    ruby_info[:physGeo][:heads]     = real_info.get_uint32(Info.offset_of(:physGeo) + Geometry.offset_of(:heads))
    ruby_info[:physGeo][:sectors]   = real_info.get_uint32(Info.offset_of(:physGeo) + Geometry.offset_of(:sectors))
    ruby_info[:capacity]            = real_info.get_uint64(Info.offset_of(:capacity))
    ruby_info[:adapterType]         = real_info.get_int(Info.offset_of(:adapterType))
    ruby_info[:numLinks]            = real_info.get_int(Info.offset_of(:numLinks))

    parent_info = real_info + Info.offset_of(:parentFileNameHint)
    parent_info_str = parent_info.read_pointer
    ruby_info[:parentFileNameHint]  = parent_info_str.read_string unless parent_info_str.null?
    uuid_info = real_info + Info.offset_of(:uuid)
    uuid_info_str = uuid_info.read_pointer
    ruby_info[:uuid]                = uuid_info_str.read_string unless uuid_info_str.null?
    freeinfo(real_info)
    @info = ruby_info
  end
end # class DiskInfo
