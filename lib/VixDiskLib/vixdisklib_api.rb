# encoding: US-ASCII

require 'vixdisklib_ffi'

class VixDiskLibError < RuntimeError
end

class VixDiskLibApi
  extend FFI::VixDiskLib::API
  VixDiskLib = FFI::VixDiskLib::API
  require 'vixdisklib_info'
  require 'safe_connect_params'
  require 'safe_create_params'
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
    snapshot_ptr = snapshot_ref && FFI::MemoryPointer.from_string(snapshot_ref)
    modes_ptr = transport_modes && FFI::MemoryPointer.from_string(transport_modes)
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

  private

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
