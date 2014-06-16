require 'vixdisklib_api'

class SafeConnectParams < VixDiskLibApi
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
    @user_name = in_creds[:userName] && FFI::MemoryPointer.from_string(in_creds[:userName])
    conn_parms.put_pointer(0, @user_name)
    # Increment structure pointer to creds field's password
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:uid) + UidPasswd.offset_of(:password)
    @password = in_creds[:password] && FFI::MemoryPointer.from_string(in_creds[:password])
    conn_parms.put_pointer(0, @password)
  end

  def get_safe_sessionid_creds(in_creds, out_cred_ptr)
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:sessionId) + SessionId.offset_of(:cookie)
    @cookie = in_creds[:cookie] && FFI::MemoryPointer.from_string(in_creds[:cookie])
    conn_parms.put_pointer(0, @cookie)
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:sessionId) + SessionId.offset_of(:sessionUserName)
    @session_user_name = in_creds[:sessionUserName] && FFI::MemoryPointer.from_string(in_creds[:sessionUserName])
    conn_parms.put_pointer(0, @session_user_name)
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:sessionId) + SessionId.offset_of(:key)
    @key = in_creds[:key] && FFI::MemoryPointer.from_string(in_creds[:key])
    conn_parms.put_pointer(0, @key)
  end

  def get_safe_ticketid_creds(in_creds, out_cred_ptr)
    conn_parms = out_cred_ptr + VixDiskLib::Creds.offset_of(:ticketId) + SessionId.offset_of(:dummy)
    @dummy = in_creds[:dummy] && FFI::MemoryPointer.from_string(in_creds[:dummy])
    conn_parms.put_pointer(0, @dummy)
  end
end # class SafeConnectParams
