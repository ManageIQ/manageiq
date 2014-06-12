require 'vixdisklib_ffi'

class VixDiskLibError < RuntimeError
end

class VixDiskLibApi
  extend FFI::VixDiskLib::API
  VixDiskLib = FFI::VixDiskLib::API
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
    check_error(vix_error, __method__)
    connection
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
    if vix_error != VixDiskLib::VixErrorType[:VIX_OK] &&
       vix_error != VixDiskLib::VixErrorType[:VIX_E_BUFFER_TOOSMALL]
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

    vix_error = super(FFI::VixDiskLib::API::VERSION_MAJOR, FFI::VixDiskLib::API::VERSION_MINOR,
                      logger_for("info"), logger_for("warn"), logger_for("error"), libDir)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_InitEx method
  #
  def self.init_ex(info_logger = nil, warn_logger = nil, error_logger = nil, libDir = nil, configFile = nil)
    @info_logger, @warn_logger, @error_logger = info_logger, warn_logger, error_logger

    vix_error = super(FFI::VixDiskLib::API::VERSION_MAJOR, FFI::VixDiskLib::API::VERSION_MINOR,
                      logger_for("info"), logger_for("warn"), logger_for("error"), libDir, configFile)
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_IsAttachPossible method
  #
  def self.is_attach_possible(parent_disk_handle, child_disk_handle)
    vix_error = super(parent_disk_handle, child_disk_handle)
    VixDiskLib.vix_succeeded?(vix_error)
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
    check_error(vix_error, __method__)
    nil
  end

  #
  # The VixDiskLib_Read method
  #
  def self.read(disk_handle, start_sector, num_sectors)
    buf_size = num_sectors * FFI::VixDiskLib::API::VIXDISKLIB_SECTOR_SIZE
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
    if vix_error != VixDiskLib::VixErrorType[:VIX_OK] &&
       vix_error != VixDiskLib::VixErrorType[:VIX_E_BUFFER_TOOSMALL]
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

  INFO_LOGGER = proc do |fmt, args|
    if @info_logger.nil?
      if $vim_log
        $vim_log.info "VMware(VixDiskLib): #{process_log_args(fmt, args)}"
      else
        puts "INFO: VMware(VixDiskLib): #{process_log_args(fmt, args)}"
      end
    else
      @info_logger.call(process_log_args(fmt, args))
    end
    # @info_logger.nil? ? process_log_args(fmt, args) : @info_logger.call(process_log_args(fmt, args))
  end

  WARN_LOGGER = proc do |fmt, args|
    if @warn_logger.nil?
      if $vim_log
        $vim_log.warn "VMware(VixDiskLib): #{process_log_args(fmt, args)}"
      else
        puts "WARN: VMware(VixDiskLib): #{process_log_args(fmt, args)}"
      end
    else
      @warn_logger.call(process_log_args(fmt, args))
    end
    # @warn_logger.nil? ? process_log_args(fmt, args) : @warn_logger.call(process_log_args(fmt, args))
  end

  ERROR_LOGGER = proc do |fmt, args|
    if @error_logger.nil?
      if $vim_log
        $vim_log.error "VMware(VixDiskLib): #{process_log_args(fmt, args)}"
      else
        puts "ERROR: VMware(VixDiskLib): #{process_log_args(fmt, args)}"
      end
    else
      @error_logger.call(process_log_args(fmt, args))
    end
    # @error_logger.nil? ? process_log_args(fmt, args) : @error_logger.call(process_log_args(fmt, args))
  end

  def self.logger_for(level)
    instance_variable_get("@#{level.downcase}_logger") && const_get("#{level.upcase}_LOGGER")
  end

  def self.process_log_args(fmt, args)
    buf = FFI::MemoryPointer.new(:char, 1024, true)
    VixDiskLib.vsnprintf(buf, 1024, fmt, args)
    buf.read_string.chomp
  end

  def self.check_error(err, method)
    if VixDiskLib.vix_failed?(err)
      err_msg = getErrorText(err, nil)
      err_code = VixDiskLib.vix_error_code(err)
      err_name = VixDiskLib::VixErrorType[err_code]
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
end # class VixDiskLibApi

class SafeConnectParams
  extend FFI::VixDiskLib::API
  VixDiskLib = FFI::VixDiskLib::API
  UidPasswd = VixDiskLib::UidPasswdCreds
  SessionId = VixDiskLib::SessionIdCreds
  #
  # Read the contents of a ConnectParams structure
  # into FFI memory for use when calling out to VixDiskLib
  #
  attr_reader :connect_params
  def initialize(in_conn_parms)
    conn_parms = FFI::MemoryPointer.new(VixDiskLib::ConnectParams, 1, true)
    @connect_params = conn_parms
    conn_parms = @connect_params + VixDiskLib::ConnectParams.offset_of(:vmxSpec)
    # Structure pointer (conn_parms) starts with vmxSpec
    @vmx_spec = get_mem_ptr_from_str(in_conn_parms[:vmxSpec])
    conn_parms.put_pointer(0, @vmx_spec)
    # Increment structure pointer to server_name
    conn_parms = @connect_params + VixDiskLib::ConnectParams.offset_of(:serverName)
    @server_name = get_mem_ptr_from_str(in_conn_parms[:serverName])
    conn_parms.put_pointer(0, @server_name)
    # Increment structure pointer to thumbPrint
    conn_parms = @connect_params + VixDiskLib::ConnectParams.offset_of(:thumbPrint)
    @thumb_print = get_mem_ptr_from_str(in_conn_parms[:thumbPrint])
    conn_parms.put_pointer(0, @thumb_print)
    # Increment structure pointer to privateUse
    conn_parms = @connect_params + VixDiskLib::ConnectParams.offset_of(:privateUse)
    conn_parms.write_long(in_conn_parms[:privateUse]) unless in_conn_parms[:privateUse].nil?
    # Increment structure pointer to credType
    cred_type = in_conn_parms[:credType]
    conn_parms = @connect_params + VixDiskLib::ConnectParams.offset_of(:credType)
    conn_parms.write_int(cred_type) unless cred_type.nil?
    get_safe_creds(cred_type, in_conn_parms, @connect_params + VixDiskLib::ConnectParams.offset_of(:creds))
    conn_parms = @connect_params + VixDiskLib::ConnectParams.offset_of(:port)
    conn_parms.write_uint32(in_conn_parms[:port]) unless in_conn_parms[:port].nil?
    @connect_params
  end

  #
  # Read a ConnectParams structure returned from the FFI layer from VixDiskLib_GetConnectParams
  # into a ruby hash.
  #
  def self.read(ffi_connect_parms)
    out_connect_parms = {}
    spec_ptr = ffi_connect_parms.get_pointer(VixDiskLib::ConnectParams.offset_of(:vmxSpec))
    out_connect_parms[:vmxSpec] = spec_ptr.read_string unless spec_ptr.null?
    serv_ptr = ffi_connect_parms.get_pointer(VixDiskLib::ConnectParams.offset_of(:serverName))
    out_connect_parms[:serverName] = serv_ptr.read_string unless serv_ptr.null?
    thumb_ptr = ffi_connect_parms.get_pointer(VixDiskLib::ConnectParams.offset_of(:thumbPrint))
    out_connect_parms[:thumbPrint] = thumb_ptr.read_string unless thumb_ptr.null?
    out_connect_parms[:privateUse] = ffi_connect_parms.get_long(VixDiskLib::ConnectParams.offset_of(:privateUse))
    out_connect_parms[:credType] = ffi_connect_parms.get_long(VixDiskLib::ConnectParams.offset_of(:credType))
    cred_type = out_connect_parms[:credType]
    read_creds(cred_type, out_connect_parms, ffi_connect_parms + VixDiskLib::ConnectParams.offset_of(:creds))
    out_connect_parms
  end

  #
  # Read a ConnectParams Creds sub-structure returned from the FFI layer from VixDiskLib_GetConnectParams
  # into a ruby hash.
  #
  def self.read_creds(cred_type, conn_parms, ffi_creds)
    if cred_type == VixDiskLib::CredType[:VIXDISKLIB_CRED_UID]
      user_ptr = ffi_creds + VixDiskLib::Creds.offset_of(:uid) + UidPasswd.offset_of(:userName)
      conn_parms[:userName] = read_safe_str_from_mem(user_ptr)
      pass_ptr = ffi_creds + VixDiskLib::Creds.offset_of(:uid) + UidPasswd.offset_of(:password)
      conn_parms[:password] = read_safe_str_from_mem(pass_ptr)
    elsif cred_type == VixDiskLib::CredType[:VIXDISKLIB_CRED_SESSIONID]
      cookie_ptr = ffi_creds + VixDiskLib::Creds.offset_of(:sessionId) + UidPasswd.offset_of(:cookie)
      conn_parms[:cookie] = read_safe_str_from_mem(cookie_ptr)
      user_ptr = ffi_creds + VixDiskLib::Creds.offset_of(:sessionId) + UidPasswd.offset_of(:sessionUserName)
      conn_parms[:sessionUserName] = read_safe_str_from_mem(user_ptr)
      key_ptr = ffi_creds + VixDiskLib::Creds.offset_of(:sessionId) + UidPasswd.offset_of(:key)
      conn_parms[:key] = read_safe_str_from_mem(key_ptr)
    elsif cred_type == VixDiskLib::CredType[:VIXDISKLIB_CRED_TICKETID]
      dummy_ptr = ffi_creds + VixDiskLib::Creds.offset_of(:ticketId) + UidPasswd.offset_of(:dummy)
      conn_parms[:dummy] = read_safe_str_from_mem(dummy_ptr)
    end
  end

  private

  def self.read_safe_str_from_mem(mem_ptr)
    mem_str = mem_ptr.read_pointer
    mem_str.read_string unless mem_str.null?
  end

  def get_mem_ptr_from_str(str)
    return nil if str.nil?
    FFI::MemoryPointer.from_string(str)
  end

  def get_safe_creds(cred_type, in_creds, out_cred_ptr)
    if cred_type == FFI::VixDiskLib::API::VIXDISKLIB_CRED_UID
      get_safe_uid_creds(in_creds, out_cred_ptr)
    elsif cred_type == FFI::VixDiskLib::API::VIXDISKLIB_CRED_SESSIONID
      get_safe_sessionid_creds(in_creds, out_cred_ptr)
    elsif cred_type == FFI::VixDiskLib::API::VIXDISKLIB_CRED_TICKETID
      get_safe_ticketid_creds(in_creds, out_cred_ptr)
    elsif cred_type == FFI::VixDiskLib::API::VIXDISKLIB_CRED_SSPI
      $vim_log.error "VixDiskLibApi.connect - Connection Parameters Credentials Type SSPI"
    elsif cred_type == FFI::VixDiskLib::API::VIXDISKLIB_CRED_UNKNOWN
      $vim_log.error "VixDiskLibApi.connect - unknown Connection Parameters Credentials Type"
    end
  end

  def get_safe_uid_creds(in_creds, out_cred_ptr)
    # Increment structure pointer to creds field's username
    # This should take care of any padding necessary for the Union.
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:uid) + UidPasswd.offset_of(:userName)
    @user_name = in_creds[:userName].nil? ? nil : FFI::MemoryPointer.from_string(in_creds[:userName])
    conn_parms.put_pointer(0, @user_name)
    # Increment structure pointer to creds field's password
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:uid) + UidPasswd.offset_of(:password)
    @password = in_creds[:password].nil? ? nil : FFI::MemoryPointer.from_string(in_creds[:password])
    conn_parms.put_pointer(0, @password)
  end

  def get_safe_sessionid_creds(in_creds, out_cred_ptr)
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:sessionId) + SessionId.offset_of(:cookie)
    @cookie = in_creds[:cookie].nil? ? nil : FFI::MemoryPointer.from_string(in_creds[:cookie])
    conn_parms.put_pointer(0, @cookie)
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:sessionId) + SessionId.offset_of(:sessionUserName)
    @session_user_name = in_creds[:sessionUserName].nil? ? nil :
                         FFI::MemoryPointer.from_string(in_creds[:sessionUserName])
    conn_parms.put_pointer(0, @session_user_name)
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:sessionId) + SessionId.offset_of(:key)
    @key = in_creds[:key].nil? ? nil : FFI::MemoryPointer.from_string(in_creds[:key])
    conn_parms.put_pointer(0, @key)
  end

  def get_safe_ticketid_creds(in_creds, out_cred_ptr)
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:ticketId) + SessionId.offset_of(:dummy)
    @dummy = in_creds[:dummy].nil? ? nil : FFI::MemoryPointer.from_string(in_creds[:dummy])
    conn_parms.put_pointer(0, @dummy)
  end
end # class SafeConnectParams

class SafeCreateParams
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
