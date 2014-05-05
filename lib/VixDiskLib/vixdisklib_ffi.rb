
require 'ffi'

class VixDiskLibFFI
  extend FFI::Library

  def enum(*args)
    super.tab do |e|
      # Expose enums as constants
      e.symbols.each { |s| const_set(s, e[s]) }
    end
  end

  def attach_function(*args)
    super
  rescue FFI::NotFoundError
    warn "unable to attach #{args.first}"
  end

  #
  # Make sure we load one and only one version of VixDiskLib
  #
  version_load_order = %w( 5.5.0 5.1.0 5.0.0 1.2.0 1.1.2 )
  load_errors = []
  loaded_library = ""
  version_load_order.each do |version|
    begin
      loaded_library = ffi_lib ["vixDiskLib.so.#{version}"]
      VERSION_MAJOR, VERSION_MINOR = loaded_library.first.name.split(".")[2, 2].map(&:to_i)
      break
    rescue LoadError => err
      load_errors << "VixDiskLibFFI: failed to load #{version} version with error: #{err.message}."
      next
    end
  end

  unless loaded_library.length > 0
    STDERR.puts load_errors.join("\n")
    raise LoadError, "VixDiskLibFFI: failed to load any version of VixDiskLib!"
  end
  LOADED_LIBRARY = loaded_library

  typedef :char, :Bool

  # An error is a 64-bit value. If there is no error, then the value is
  # set to VIX_OK. If there is an error, then the least significant bits
  # will be set to one of the integer error codes defined below. The more
  # significant bits may or may not be set to various values, depending on
  # the errors.

  typedef :uint64, :VixError

  # The error codes are returned by all public VIX routines.
  VixErrorType = enum(
    :VIX_OK, 0,

    # General errors
    :VIX_E_FAIL, 1,
    :VIX_E_OUT_OF_MEMORY, 2,
    :VIX_E_INVALID_ARG, 3,
    :VIX_E_FILE_NOT_FOUND, 4,
    :VIX_E_OBJECT_IS_BUSY, 5,
    :VIX_E_NOT_SUPPORTED, 6,
    :VIX_E_FILE_ERROR, 7,
    :VIX_E_DISK_FULL, 8,
    :VIX_E_INCORRECT_FILE_TYPE, 9,
    :VIX_E_CANCELLED, 10,
    :VIX_E_FILE_READ_ONLY, 11,
    :VIX_E_FILE_ALREADY_EXISTS, 12,
    :VIX_E_FILE_ACCESS_ERROR, 13,
    :VIX_E_REQUIRES_LARGE_FILES, 14,
    :VIX_E_FILE_ALREADY_LOCKED, 15,
    :VIX_E_VMDB, 16,
    :VIX_E_NOT_SUPPORTED_ON_REMOTE_OBJECT, 20,
    :VIX_E_FILE_TOO_BIG, 21,
    :VIX_E_FILE_NAME_INVALID, 22,
    :VIX_E_ALREADY_EXISTS, 23,
    :VIX_E_BUFFER_TOOSMALL, 24,
    :VIX_E_OBJECT_NOT_FOUND, 25,
    :VIX_E_HOST_NOT_CONNECTED, 26,
    :VIX_E_INVALID_UTF8_STRING, 27,
    :VIX_E_OPERATION_ALREADY_IN_PROGRESS, 31,
    :VIX_E_UNFINISHED_JOB, 29,
    :VIX_E_NEED_KEY, 30,
    :VIX_E_LICENSE, 32,
    :VIX_E_VM_HOST_DISCONNECTED, 34,
    :VIX_E_AUTHENTICATION_FAIL, 35,
    :VIX_E_HOST_CONNECTION_LOST, 36,
    :VIX_E_DUPLICATE_NAME, 41,

    # Handle Errors
    :VIX_E_INVALID_HANDLE, 1000,
    :VIX_E_NOT_SUPPORTED_ON_HANDLE_TYPE, 1001,
    :VIX_E_TOO_MANY_HANDLES, 1002,

    # XML errors
    :VIX_E_NOT_FOUND, 2000,
    :VIX_E_TYPE_MISMATCH, 2001,
    :VIX_E_INVALID_XML, 2002,

    # VM Control Errors
    :VIX_E_TIMEOUT_WAITING_FOR_TOOLS, 3000,
    :VIX_E_UNRECOGNIZED_COMMAND, 3001,
    :VIX_E_OP_NOT_SUPPORTED_ON_GUEST, 3003,
    :VIX_E_PROGRAM_NOT_STARTED, 3004,
    :VIX_E_CANNOT_START_READ_ONLY_VM, 3005,
    :VIX_E_VM_NOT_RUNNING, 3006,
    :VIX_E_VM_IS_RUNNING, 3007,
    :VIX_E_CANNOT_CONNECT_TO_VM, 3008,
    :VIX_E_POWEROP_SCRIPTS_NOT_AVAILABLE, 3009,
    :VIX_E_NO_GUEST_OS_INSTALLED, 3010,
    :VIX_E_VM_INSUFFICIENT_HOST_MEMORY, 3011,
    :VIX_E_SUSPEND_ERROR, 3012,
    :VIX_E_VM_NOT_ENOUGH_CPUS, 3013,
    :VIX_E_HOST_USER_PERMISSIONS, 3014,
    :VIX_E_GUEST_USER_PERMISSIONS, 3015,
    :VIX_E_TOOLS_NOT_RUNNING, 3016,
    :VIX_E_GUEST_OPERATIONS_PROHIBITED, 3017,
    :VIX_E_ANON_GUEST_OPERATIONS_PROHIBITED, 3018,
    :VIX_E_ROOT_GUEST_OPERATIONS_PROHIBITED, 3019,
    :VIX_E_MISSING_ANON_GUEST_ACCOUNT, 3023,
    :VIX_E_CANNOT_AUTHENTICATE_WITH_GUEST, 3024,
    :VIX_E_UNRECOGNIZED_COMMAND_IN_GUEST, 3025,
    :VIX_E_CONSOLE_GUEST_OPERATIONS_PROHIBITED, 3026,
    :VIX_E_MUST_BE_CONSOLE_USER, 3027,
    :VIX_E_VMX_MSG_DIALOG_AND_NO_UI, 3028,
    # VIX_E_NOT_ALLOWED_DURING_VM_RECORDING, 3029, Removed in version 1.11
    # VIX_E_NOT_ALLOWED_DURING_VM_REPLAY, 3030, Removed in version 1.11
    :VIX_E_OPERATION_NOT_ALLOWED_FOR_LOGIN_TYPE, 3031,
    :VIX_E_LOGIN_TYPE_NOT_SUPPORTED, 3032,
    :VIX_E_EMPTY_PASSWORD_NOT_ALLOWED_IN_GUEST, 3033,
    :VIX_E_INTERACTIVE_SESSION_NOT_PRESENT, 3034,
    :VIX_E_INTERACTIVE_SESSION_USER_MISMATCH, 3035,
    # VIX_E_UNABLE_TO_REPLAY_VM, 3039, Removed in version 1.11
    :VIX_E_CANNOT_POWER_ON_VM, 3041,
    :VIX_E_NO_DISPLAY_SERVER, 3043,
    # VIX_E_VM_NOT_RECORDING, 3044, Removed in version 1.11
    # VIX_E_VM_NOT_REPLAYING, 3045, Removed in version 1.11
    :VIX_E_TOO_MANY_LOGONS, 3046,
    :VIX_E_INVALID_AUTHENTICATION_SESSION, 3047,

    # VM Errors
    :VIX_E_VM_NOT_FOUND, 4000,
    :VIX_E_NOT_SUPPORTED_FOR_VM_VERSION, 4001,
    :VIX_E_CANNOT_READ_VM_CONFIG, 4002,
    :VIX_E_TEMPLATE_VM, 4003,
    :VIX_E_VM_ALREADY_LOADED, 4004,
    :VIX_E_VM_ALREADY_UP_TO_DATE, 4006,
    :VIX_E_VM_UNSUPPORTED_GUEST, 4011,

    # Property Errors
    :VIX_E_UNRECOGNIZED_PROPERTY, 6000,
    :VIX_E_INVALID_PROPERTY_VALUE, 6001,
    :VIX_E_READ_ONLY_PROPERTY, 6002,
    :VIX_E_MISSING_REQUIRED_PROPERTY, 6003,
    :VIX_E_INVALID_SERIALIZED_DATA, 6004,
    :VIX_E_PROPERTY_TYPE_MISMATCH, 6005,

    # Completion Errors
    :VIX_E_BAD_VM_INDEX, 8000,

    # Message errors
    :VIX_E_INVALID_MESSAGE_HEADER, 10_000,
    :VIX_E_INVALID_MESSAGE_BODY, 10_001,

    # Snapshot errors
    :VIX_E_SNAPSHOT_INVAL, 13_000,
    :VIX_E_SNAPSHOT_DUMPER, 13_001,
    :VIX_E_SNAPSHOT_DISKLIB, 13_002,
    :VIX_E_SNAPSHOT_NOTFOUND, 13_003,
    :VIX_E_SNAPSHOT_EXISTS, 13_004,
    :VIX_E_SNAPSHOT_VERSION, 13_005,
    :VIX_E_SNAPSHOT_NOPERM, 13_006,
    :VIX_E_SNAPSHOT_CONFIG, 13_007,
    :VIX_E_SNAPSHOT_NOCHANGE, 13_008,
    :VIX_E_SNAPSHOT_CHECKPOINT, 13_009,
    :VIX_E_SNAPSHOT_LOCKED, 13_010,
    :VIX_E_SNAPSHOT_INCONSISTENT, 13_011,
    :VIX_E_SNAPSHOT_NAMETOOLONG, 13_012,
    :VIX_E_SNAPSHOT_VIXFILE, 13_013,
    :VIX_E_SNAPSHOT_DISKLOCKED, 13_014,
    :VIX_E_SNAPSHOT_DUPLICATEDDISK, 13_015,
    :VIX_E_SNAPSHOT_INDEPENDENTDISK, 13_016,
    :VIX_E_SNAPSHOT_NONUNIQUE_NAME, 13_017,
    :VIX_E_SNAPSHOT_MEMORY_ON_INDEPENDENT_DISK, 13_018,
    :VIX_E_SNAPSHOT_MAXSNAPSHOTS, 13_019,
    :VIX_E_SNAPSHOT_MIN_FREE_SPACE, 13_020,
    :VIX_E_SNAPSHOT_HIERARCHY_TOODEEP, 13_021,
    :VIX_E_SNAPSHOT_RRSUSPEND, 13_022,
    :VIX_E_SNAPSHOT_NOT_REVERTABLE, 13_024,

    # Host Errors
    :VIX_E_HOST_DISK_INVALID_VALUE, 14_003,
    :VIX_E_HOST_DISK_SECTORSIZE, 14_004,
    :VIX_E_HOST_FILE_ERROR_EOF, 14_005,
    :VIX_E_HOST_NETBLKDEV_HANDSHAKE, 14_006,
    :VIX_E_HOST_SOCKET_CREATION_ERROR, 14_007,
    :VIX_E_HOST_SERVER_NOT_FOUND, 14_008,
    :VIX_E_HOST_NETWORK_CONN_REFUSED, 14_009,
    :VIX_E_HOST_TCP_SOCKET_ERROR, 14_010,
    :VIX_E_HOST_TCP_CONN_LOST, 14_011,
    :VIX_E_HOST_NBD_HASHFILE_VOLUME, 14_012,
    :VIX_E_HOST_NBD_HASHFILE_INIT, 14_013,

    # Disklib errors
    :VIX_E_DISK_INVAL, 16_000,
    :VIX_E_DISK_NOINIT, 16_001,
    :VIX_E_DISK_NOIO, 16_002,
    :VIX_E_DISK_PARTIALCHAIN, 16_003,
    :VIX_E_DISK_NEEDSREPAIR, 16_006,
    :VIX_E_DISK_OUTOFRANGE, 16_007,
    :VIX_E_DISK_CID_MISMATCH, 16_008,
    :VIX_E_DISK_CANTSHRINK, 16_009,
    :VIX_E_DISK_PARTMISMATCH, 16_010,
    :VIX_E_DISK_UNSUPPORTEDDISKVERSION, 16_011,
    :VIX_E_DISK_OPENPARENT, 16_012,
    :VIX_E_DISK_NOTSUPPORTED, 16_013,
    :VIX_E_DISK_NEEDKEY, 16_014,
    :VIX_E_DISK_NOKEYOVERRIDE, 16_015,
    :VIX_E_DISK_NOTENCRYPTED, 16_016,
    :VIX_E_DISK_NOKEY, 16_017,
    :VIX_E_DISK_INVALIDPARTITIONTABLE, 16_018,
    :VIX_E_DISK_NOTNORMAL, 16_019,
    :VIX_E_DISK_NOTENCDESC, 16_020,
    :VIX_E_DISK_NEEDVMFS, 16_022,
    :VIX_E_DISK_RAWTOOBIG, 16_024,
    :VIX_E_DISK_TOOMANYOPENFILES, 16_027,
    :VIX_E_DISK_TOOMANYREDO, 16_028,
    :VIX_E_DISK_RAWTOOSMALL, 16_029,
    :VIX_E_DISK_INVALIDCHAIN, 16_030,
    :VIX_E_DISK_KEY_NOTFOUND, 16_052, # metadata key is not found
    :VIX_E_DISK_SUBSYSTEM_INIT_FAIL, 16_053,
    :VIX_E_DISK_INVALID_CONNECTION, 16_054,
    :VIX_E_DISK_ENCODING, 16_061,
    :VIX_E_DISK_CANTREPAIR, 16_062,
    :VIX_E_DISK_INVALIDDISK, 16_063,
    :VIX_E_DISK_NOLICENSE, 16_064,
    :VIX_E_DISK_NODEVICE, 16_065,
    :VIX_E_DISK_UNSUPPORTEDDEVICE, 16_066,
    :VIX_E_DISK_CAPACITY_MISMATCH, 16_067,
    :VIX_E_DISK_PARENT_NOTALLOWED, 16_068,
    :VIX_E_DISK_ATTACH_ROOTLINK, 16_069,

    # Crypto Library Errors
    :VIX_E_CRYPTO_UNKNOWN_ALGORITHM, 17_000,
    :VIX_E_CRYPTO_BAD_BUFFER_SIZE, 17_001,
    :VIX_E_CRYPTO_INVALID_OPERATION, 17_002,
    :VIX_E_CRYPTO_RANDOM_DEVICE, 17_003,
    :VIX_E_CRYPTO_NEED_PASSWORD, 17_004,
    :VIX_E_CRYPTO_BAD_PASSWORD, 17_005,
    :VIX_E_CRYPTO_NOT_IN_DICTIONARY, 17_006,
    :VIX_E_CRYPTO_NO_CRYPTO, 17_007,
    :VIX_E_CRYPTO_ERROR, 17_008,
    :VIX_E_CRYPTO_BAD_FORMAT, 17_009,
    :VIX_E_CRYPTO_LOCKED, 17_010,
    :VIX_E_CRYPTO_EMPTY, 17_011,
    :VIX_E_CRYPTO_KEYSAFE_LOCATOR, 17_012,

    # Remoting Errors.
    :VIX_E_CANNOT_CONNECT_TO_HOST, 18_000,
    :VIX_E_NOT_FOR_REMOTE_HOST, 18_001,
    :VIX_E_INVALID_HOSTNAME_SPECIFICATION, 18_002,

    # Screen Capture Errors.
    :VIX_E_SCREEN_CAPTURE_ERROR, 19_000,
    :VIX_E_SCREEN_CAPTURE_BAD_FORMAT, 19_001,
    :VIX_E_SCREEN_CAPTURE_COMPRESSION_FAIL, 19_002,
    :VIX_E_SCREEN_CAPTURE_LARGE_DATA, 19_003,

    # Guest Errors
    :VIX_E_GUEST_VOLUMES_NOT_FROZEN, 20_000,
    :VIX_E_NOT_A_FILE, 20_001,
    :VIX_E_NOT_A_DIRECTORY, 20_002,
    :VIX_E_NO_SUCH_PROCESS, 20_003,
    :VIX_E_FILE_NAME_TOO_LONG, 20_004,
    :VIX_E_OPERATION_DISABLED, 20_005,

    # Tools install errors
    :VIX_E_TOOLS_INSTALL_NO_IMAGE, 21_000,
    :VIX_E_TOOLS_INSTALL_IMAGE_INACCESIBLE, 21_001,
    :VIX_E_TOOLS_INSTALL_NO_DEVICE, 21_002,
    :VIX_E_TOOLS_INSTALL_DEVICE_NOT_CONNECTED, 21_003,
    :VIX_E_TOOLS_INSTALL_CANCELLED, 21_004,
    :VIX_E_TOOLS_INSTALL_INIT_FAILED, 21_005,
    :VIX_E_TOOLS_INSTALL_AUTO_NOT_SUPPORTED, 21_006,
    :VIX_E_TOOLS_INSTALL_GUEST_NOT_READY, 21_007,
    :VIX_E_TOOLS_INSTALL_SIG_CHECK_FAILED, 21_008,
    :VIX_E_TOOLS_INSTALL_ERROR, 21_009,
    :VIX_E_TOOLS_INSTALL_ALREADY_UP_TO_DATE, 21_010,
    :VIX_E_TOOLS_INSTALL_IN_PROGRESS, 21_011,
    :VIX_E_TOOLS_INSTALL_IMAGE_COPY_FAILED, 21_012,

    # Wrapper Errors
    :VIX_E_WRAPPER_WORKSTATION_NOT_INSTALLED, 22_001,
    :VIX_E_WRAPPER_VERSION_NOT_FOUND, 22_002,
    :VIX_E_WRAPPER_SERVICEPROVIDER_NOT_FOUND, 22_003,
    :VIX_E_WRAPPER_PLAYER_NOT_INSTALLED, 22_004,
    :VIX_E_WRAPPER_RUNTIME_NOT_INSTALLED, 22_005,
    :VIX_E_WRAPPER_MULTIPLE_SERVICEPROVIDERS, 22_006,

    # FuseMnt errors
    :VIX_E_MNTAPI_MOUNTPT_NOT_FOUND, 24_000,
    :VIX_E_MNTAPI_MOUNTPT_IN_USE, 24_001,
    :VIX_E_MNTAPI_DISK_NOT_FOUND, 24_002,
    :VIX_E_MNTAPI_DISK_NOT_MOUNTED, 24_003,
    :VIX_E_MNTAPI_DISK_IS_MOUNTED, 24_004,
    :VIX_E_MNTAPI_DISK_NOT_SAFE, 24_005,
    :VIX_E_MNTAPI_DISK_CANT_OPEN, 24_006,
    :VIX_E_MNTAPI_CANT_READ_PARTS, 24_007,
    :VIX_E_MNTAPI_UMOUNT_APP_NOT_FOUND, 24_008,
    :VIX_E_MNTAPI_UMOUNT, 24_009,
    :VIX_E_MNTAPI_NO_MOUNTABLE_PARTITONS, 24_010,
    :VIX_E_MNTAPI_PARTITION_RANGE, 24_011,
    :VIX_E_MNTAPI_PERM, 24_012,
    :VIX_E_MNTAPI_DICT, 24_013,
    :VIX_E_MNTAPI_DICT_LOCKED, 24_014,
    :VIX_E_MNTAPI_OPEN_HANDLES, 24_015,
    :VIX_E_MNTAPI_CANT_MAKE_VAR_DIR, 24_016,
    :VIX_E_MNTAPI_NO_ROOT, 24_017,
    :VIX_E_MNTAPI_LOOP_FAILED, 24_018,
    :VIX_E_MNTAPI_DAEMON, 24_019,
    :VIX_E_MNTAPI_INTERNAL, 24_020,
    :VIX_E_MNTAPI_SYSTEM, 24_021,
    :VIX_E_MNTAPI_NO_CONNECTION_DETAILS, 24_022,
    # FuseMnt errors: Do not exceed 24299

    # VixMntapi errors
    :VIX_E_MNTAPI_INCOMPATIBLE_VERSION, 24_300,
    :VIX_E_MNTAPI_OS_ERROR, 24_301,
    :VIX_E_MNTAPI_DRIVE_LETTER_IN_USE, 24_302,
    :VIX_E_MNTAPI_DRIVE_LETTER_ALREADY_ASSIGNED, 24_303,
    :VIX_E_MNTAPI_VOLUME_NOT_MOUNTED, 24_304,
    :VIX_E_MNTAPI_VOLUME_ALREADY_MOUNTED, 24_305,
    :VIX_E_MNTAPI_FORMAT_FAILURE, 24_306,
    :VIX_E_MNTAPI_NO_DRIVER, 24_307,
    :VIX_E_MNTAPI_ALREADY_OPENED, 24_308,
    :VIX_E_MNTAPI_ITEM_NOT_FOUND, 24_309,
    :VIX_E_MNTAPI_UNSUPPROTED_BOOT_LOADER, 24_310,
    :VIX_E_MNTAPI_UNSUPPROTED_OS, 24_311,
    :VIX_E_MNTAPI_CODECONVERSION, 24_312,
    :VIX_E_MNTAPI_REGWRITE_ERROR, 24_313,
    :VIX_E_MNTAPI_UNSUPPORTED_FT_VOLUME, 24_314,
    :VIX_E_MNTAPI_PARTITION_NOT_FOUND, 24_315,
    :VIX_E_MNTAPI_PUTFILE_ERROR, 24_316,
    :VIX_E_MNTAPI_GETFILE_ERROR, 24_317,
    :VIX_E_MNTAPI_REG_NOT_OPENED, 24_318,
    :VIX_E_MNTAPI_REGDELKEY_ERROR, 24_319,
    :VIX_E_MNTAPI_CREATE_PARTITIONTABLE_ERROR, 24_320,
    :VIX_E_MNTAPI_OPEN_FAILURE, 24_321,
    :VIX_E_MNTAPI_VOLUME_NOT_WRITABLE, 24_322,

    # Network Errors
    :VIX_E_NET_HTTP_UNSUPPORTED_PROTOCOL, 30_001,
    :VIX_E_NET_HTTP_URL_MALFORMAT, 30_003,
    :VIX_E_NET_HTTP_COULDNT_RESOLVE_PROXY, 30_005,
    :VIX_E_NET_HTTP_COULDNT_RESOLVE_HOST, 30_006,
    :VIX_E_NET_HTTP_COULDNT_CONNECT, 30_007,
    :VIX_E_NET_HTTP_HTTP_RETURNED_ERROR, 30_022,
    :VIX_E_NET_HTTP_OPERATION_TIMEDOUT, 30_028,
    :VIX_E_NET_HTTP_SSL_CONNECT_ERROR, 30_035,
    :VIX_E_NET_HTTP_TOO_MANY_REDIRECTS, 30_047,
    :VIX_E_NET_HTTP_TRANSFER, 30_200,
    :VIX_E_NET_HTTP_SSL_SECURITY, 30_201,
    :VIX_E_NET_HTTP_GENERIC, 30_202
  )

  def self.VIX_ERROR_CODE(err)
    err & 0xFFFF
  end

  def self.VIX_SUCCEEDED(err)
    err == VixErrorType[:VIX_OK]
  end

  def self.VIX_FAILED(err)
    err != VixErrorType[:VIX_OK]
  end

  typedef:uint64, :SectorType

  VIXDISKLIB_SECTOR_SIZE = 512

  # Geometry
  class Geometry < FFI::Struct
    layout :cylinders, :uint32,
           :heads,     :uint32,
           :sectors,   :uint32
  end

  # Disk types
  DiskType = enum(
    :DISK_MONOLITHIC_SPARSE, 1, # monolithic file, sparse
    :DISK_MONOLITHIC_FLAT,   2, # monolithic file, all space pre-allocated
    :DISK_SPLIT_SPARSE,      3, # disk split into 2GB extents, sparse
    :DISK_SPLIT_FLAT,        4, # disk split into 2GB extents, pre-allocated
    :DISK_VMFS_FLAT,         5, # ESX 3.0 and above flat disks
    :DISK_STREAM_OPTIMIZED,  6, # compressed monolithic sparse
    :DISK_VMFS_THIN,         7, # ESX 3.0 and above thin provisioned
    :DISK_VMFS_SPARSE,       8, # ESX 3.0 and above sparse disks
    :DISK_UNKNOWN,           256 # unknown type
  )

  # Disk adapter types
  AdapterType = enum(
    :ADAPTER_IDE,           1,
    :ADAPTER_SCSI_BUSLOGIC, 2,
    :ADAPTER_SCSI_LSILOGIC, 3,
    :ADAPTER_UNKNOWN,       256
  )

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

  # Create Params
  class CreateParams < FFI::Struct
    layout :diskType,    DiskType,
           :adapterType, AdapterType,
           :hwVersion,   :uint16,
           :capacity,    :SectorType
  end

  # Credential Type - SessionId not yet supported
  CredType = enum(
    :VIXDISKLIB_CRED_UID,         1, # use userid password
    :VIXDISKLIB_CRED_SESSIONID,   2, # http session id
    :VIXDISKLIB_CRED_TICKETID,    3, # vim ticket id
    :VIXDISKLIB_CRED_SSPI,        4, # Windows only - use current thread credentials.
    :VIXDISKLIB_CRED_UNKNOWN,     256
  )

  class UidPasswdCreds < FFI::Struct
    layout :userName, :pointer, # User id and password on the
           :password, :pointer # VC/ESX host.
  end

  class SessionIdCreds < FFI::Struct # Not supported in 1.0
    layout :cookie,          :pointer,
           :sessionUserName, :pointer,
           :key,             :pointer
  end

  class TicketIdCreds < FFI::Struct # Internal use only.
    layout :dummy, :char
  end

#  class Creds < FFI::Union
#    layout :uid,       UidPasswdCreds.by_value,
#           :sessionId, SessionIdCreds.by_value,
#           :ticketId,  TicketIdCreds
#  end
  class Creds < FFI::Union
    layout :uid,       UidPasswdCreds,
           :sessionId, SessionIdCreds,
           :ticketId,  TicketIdCreds
  end

  # ConnectParams - Connection setup parameters.
  #
  # vmxSpec is required for opening a virtual disk on a datastore through
  # the Virtual Center or ESX server.
  # vmxSpec is of the form:
  # <vmxPathName>?dcPath=<dcpath>&dsName=<dsname>
  # where
  # vmxPathName is the fullpath for the VMX file,
  # dcpath is the inventory path of the datacenter and
  # dsname is the datastore name.
  #
  # Inventory path for the datacenter can be read off the Virtual Center
  # client's inventory tree.
  #
  # Example VM spec:
  # "MyVm/MyVm.vmx?dcPath=Path/to/MyDatacenter&dsName=storage1"
  class ConnectParams < FFI::Struct
    layout :vmxSpec,    :pointer,
           :serverName, :pointer,
           :thumbPrint, :pointer,
           :privateUse, :long,
           :credType,   CredType,
           :creds,      Creds,
           :port,       :uint32
  end

  class Info < FFI::Struct
    layout :biosGeo,            Geometry.by_value, # BIOS geometry for booting and partitioning
           :physGeo,            Geometry.by_value, # physical geometry
           :capacity,           :SectorType, # total capacity in sectors
           :adapterType,        AdapterType, # adapter type
           :numLinks,           :int, # number of links (i.e. base disk + redo logs)
           :parentFileNameHint, :pointer, # parent file for a redo log
           :uuid,               :pointer # disk UUID
  end

  # Flags for open
  VIXDISKLIB_FLAG_OPEN_UNBUFFERED = (1 << 0) # disable host disk caching
  VIXDISKLIB_FLAG_OPEN_SINGLE_LINK = (1 << 1) # don't open parent disk(s)
  VIXDISKLIB_FLAG_OPEN_READ_ONLY = (1 << 2) # open read-only

  class HandleStruct < FFI::Struct
    layout :dummy, :char
  end
  typedef :pointer, :Handle

  class ConnectParam < FFI::Struct
    layout :dummy, :char
  end
  typedef :pointer, :Connection

  callback :GenericLogFunc, [:string, :pointer], :void

  # Prototype for the progress function called by VixDiskLib.
  #
  # @scope class
  # @method ProgressFunc(progress_data, percent_completed)
  # @param progress_data [FFI::Pointer(*Void)] User supplied opaque pointer.
  # @param percent_completed [Integer] Completion percent.
  # @return [Boolean] ignores the return value.
  # This function may be called with the same percentage completion
  # multiple times.
  callback :ProgressFunc, [:pointer, :int], :bool

  # Perform a cleanup after an unclean shutdown of an application using
  # VixDiskLib.
  #
  # When using VixDiskLib_ConnectEx, some state might have not been cleaned
  # up if the resulting connection was not shut down cleanly. Use
  # VixDiskLib_Cleanup to remove this extra state.
  #
  # @param connection [in] Hostname and login credentials to connect to
  #       a host managing virtual machines that were accessed and need
  #       cleanup. While VixDiskLib_Cleanup can be invoked for local
  #       connections as well, it is a no-op in that case. Also, the
  #       vmxSpec property of connectParams should be set to NULL.
  # @param numCleanedUp [out] Number of virtual machines that were
  #       successfully cleaned up. -- Can be NULL.
  # @param numRemaining [out] Number of virutal machines that still
  #       require cleaning up. -- Can be NULL.
  # @return VIX_OK if all virtual machines were successfully cleaned
  #       up or if no virtual machines required cleanup. VIX error
  #       code otherwise and numRemaning can be used to check for
  #       the number of virtual machines requiring cleanup.
  #
  attach_function :cleanup, :VixDiskLib_Cleanup,
                  [
                    ConnectParams,  # connectParams,
                    :pointer,       # numCleanedUp,
                    :pointer        # numRemaining
                  ],
                  :VixError

  # Closes the disk.
  # @param diskHandle [in] Handle to an open virtual disk.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :close, :VixDiskLib_Close,
                  [
                    :pointer       # disk handle
                  ],
                  :VixError

  # Connects to a local / remote server.
  # @param connectParams [in] NULL if manipulating local disks.
  #             For remote case this includes esx hostName and
  #             user credentials.
  # @param connection [out] Returned handle to a connection.
  # @return VIX_OK if success suitable VIX error code otherwise.
  attach_function :connect, :VixDiskLib_Connect,
                  [
                    ConnectParams, # connectParams,
                    :Connection    # connection
                  ],
                  :VixError

  # Create a transport context to access disks belonging to a
  # particular snapshot of a particular virtual machine. Using this
  # transport context will enable callers to open virtual disks using
  # the most efficient data acces protocol available for managed
  # virtual machines, hence getting better I/O performance.
  #
  # If this call is used instead of VixDiskLib_Connect, the additional
  # information passed in will be used in order to optimize the I/O
  # access path, to maximize I/O throughput.
  #
  # Note: For local virtual machines/disks, this call is equivalent
  #       to VixDiskLib_Connect.
  #
  # @param connectParams [in] NULL if maniuplating local disks.
  #             For remote case this includes esx hostName and
  #             user credentials.
  # @param readOnly [in] Should be set to TRUE if no write access is needed
  #             for the disks to be accessed through this connection. In
  #             some cases, a more efficient I/O path can be used for
  #             read-only access.
  # @param snapshotRef [in] A managed object reference to the specific
  #             snapshot of the virtual machine whose disks will be
  #             accessed with this connection.  Specifying this
  #             property is only meaningful if the vmxSpec property in
  #             connectParams is set as well.
  # @param transportModes [in] An optional list of transport modes that
  #             can be used for this connection, separated by
  #             colons. If NULL is specified, VixDiskLib's default
  #             setting of "file:san:hotadd:nbd" is used. If a disk is
  #             opened through this connection, VixDiskLib will start
  #             with the first entry of the list and attempt to use
  #             this transport mode to gain access to the virtual
  #             disk. If this does not work, the next item in the list
  #             will be used until either the disk was successfully
  #             opened or the end of the list is reached.
  # @param connection [out] Returned handle to a connection.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :connect_ex, :VixDiskLib_ConnectEx,
                  [
                    ConnectParams, # connectParams,
                    :bool,         # readOnly flag
                    :pointer,      # snapshotRef string
                    :pointer,      # transportModes string
                    :Connection    # connection
                  ],
                  :VixError

  # Creates a local disk. Remote disk creation is not supported.
  # @param connection [in] A valid connection.
  # @param path [in] VMDK file name given as absolute path
  #                  e.g. "c:\\My Virtual Machines\\MailServer\SystemDisk.vmdk".
  # @param createParams [in] Specification for the new disk (type, capacity ...).
  # @param progressFunc [in] Callback to report progress.
  # @param progressCallbackData [in] Callback data pointer.
  # @return VIX_OK if success suitable VIX error code otherwise.
  attach_function :create, :VixDiskLib_Create,
                  [
                    :Connection,      # connection,
                    :pointer,         # path,
                    CreateParams,     # createParams,
                    :ProgressFunc,    # progressFunc,
                    :pointer          # progressCallbackData
                  ],
                  :VixError

  # Creates a redo log from a parent disk.
  # @param diskHandle [in] Handle to an open virtual disk.
  # @param childPath [in] Redo log file name given as absolute path
  #                  e.g. "c:\\My Virtual Machines\\MailServer\SystemDisk_s0001.vmdk".
  # @param diskType [in] Either VIXDISKLIB_DISK_MONOLITHIC_SPARSE or
  #                      VIXDISKLIB_DISK_SPLIT_SPARSE.
  # @param progressFunc [in] Callback to report progress.
  # @param progressCallbackData [in] Callback data pointer.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :create_child, :VixDiskLib_CreateChild,
                  [
                    :pointer,          # diskHandle,
                    :pointer,          # childPath,
                    :int,              # diskType,
                    :ProgressFunc,     # progressFunc,
                    :pointer           # progressCallbackData
                  ],
                  :VixError

  # Breaks an existing connection.
  # @param connection [in] Valid handle to a (local/remote) connection.
  # @return VIX_OK if success suitable VIX error code otherwise.
  attach_function :disconnect, :VixDiskLib_Disconnect,
                  [
                    :Connection    # connection
                  ],
                  :VixError

  # This function is used to notify the host of a virtual machine that the
  # virtual machine disks are closed and that the operations which rely on the
  # virtual machine disks to be closed can now be allowed.
  #
  # @param connectParams [in] Always used for a remote connection. Must be the
  #           same parameters as used in the corresponding PrepareForAccess call.
  # @param identity [in] An arbitrary string containing the identity of the
  #           application.
  # @return VIX_OK of success, suitable VIX error code otherwise.
  attach_function :end_access, :VixDiskLib_EndAccess,
                  [
                    ConnectParams,    # connectParams,
                    :pointer          # identity string
                  ],
                  :VixError

  # Cleans up VixDiskLib.
  #
  # @scope class
  # @method exit
  # @return [nil]
  attach_function :exit, :VixDiskLib_Exit, [], :void

  # @scope class
  # @method freeErrorText(errMsg)
  # @param errMsg [FFI:Pointer(*String)] Message string returned by getErrorText.
  # It is OK to call this function with nil.
  # @return [nil]
  attach_function :freeErrorText, :VixDiskLib_FreeErrorText,
                  [
                    :pointer # errMsg to free
                  ],
                  :void

  # Returns the textual description of an error.
  #
  # @scope class
  # @method getErrorText(err, locale)
  # @param err [VixError] A VIX error code.
  # @param locale [String] Language locale - not currently supported and must be nil.
  # @return [String] The error message string. This should only be deallocated
  # by freeErrorText.
  # Returns NULL if there is an error in retrieving text.

  attach_function :getErrorText, :VixDiskLib_GetErrorText,
                  [
                    :VixError, # err
                    :pointer   # locale
                  ],
                  :pointer

  # Retrieves the list of keys in the metadata table.
  # Key names are returned as list of null-terminated strings,
  # followed by an additional NULL character.
  # @param diskHandle [in] Handle to an open virtual disk.
  # @param keys [out, optional]  Keynames buffer, can be NULL.
  # @param maxLen [in] Size of the keynames buffer.
  # @param requiredLen [out, optional] Space required for the keys including the double
  #    end-of-string  characters.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :get_metadata_keys, :VixDiskLib_GetMetadataKeys,
                  [
                    :pointer,     # diskHandle,
                    :pointer,     # keys,
                    :uint64,      # size_t maxLen,
                    :pointer,     # requiredLen
                  ],
                  :VixError

  # Returns a pointer to a static string identifying the transport mode that
  # is used to access the virtual disk's data.
  #
  # If a disk was opened through a connection obtained by VixDiskLib_Connect,
  # the return value will be "file" for a local disk and "nbd" or "nbdssl" for
  # a managed disk.
  #
  # The pointer to this string is static and must not be deallocated by the
  # caller.
  #
  # @param diskHandle [in] Handle to an open virtual disk.
  # @return Returns a pointer to a static string identifying the transport
  #         mode used to access the disk's data.
  attach_function :get_transport_mode, :VixDiskLib_GetTransportMode,
                  [
                    :pointer           # diskHandle
                  ],
                  :pointer             # transport mode

  # Free the error message returned by getErrorText.
  # Initializes VixDiskLib - deprecated, please use initEx.
  #
  # @scope class
  # @method init(majorVersion, minorVersion, log, warn, panic, libDir)
  # @param majorVersion [Integer] Required major version number for client.
  # @param minorVersion [Integer] Required minor version number for client.
  # @param log [FFI::Pointer(*GenericLogFunc)] Callback for Log entries.
  # @param warn [FFI::Pointer(*GenericLogFunc)] Callback for warnings.
  # @param panic [FFI::Pointer(*GenericLogFunc)] Callback for panic.
  # @param libDir [String] Directory location where dependent libs are located.
  # @return [VixError] VIX_OK on success, suitable VIX error code otherwise.
  attach_function :init, :VixDiskLib_Init,
                  [
                    :uint32,         # majorVersion
                    :uint32,         # minorVersion
                    :GenericLogFunc, # log
                    :GenericLogFunc, # warn
                    :GenericLogFunc, # panic
                    :string,         # libDir
                  ], :VixError

  # Initializes VixDiskLib.
  #
  # @scope class
  # @method initEx(majorVersion, minorVersion, log, warn, panic, libDir, configFile)
  # @param majorVersion [Integer] Required major version number for client.
  # @param minorVersion [Integer] Required minor version number for client.
  # @param log [FFI::Pointer(*GenericLogFunc)] Callback for Log entries.
  # @param warn [FFI::Pointer(*GenericLogFunc)] Callback for warnings.
  # @param panic [FFI::Pointer(*GenericLogFunc)] Callback for panic.
  # @param libDir [String] Directory location where dependent libs are located.
  # @param configFile [String] Configuration file path in local encoding.
  # configuration files are of the format
  # name = "value"
  # each name/value pair on a separate line. For a detailed
  # description of allowed values, refer to the
  # documentation.
  # @return [VixError] VIX_OK on success, suitable VIX error code otherwise.
  attach_function :init_ex, :VixDiskLib_InitEx,
                  [
                    :uint32,         # majorVersion
                    :uint32,         # minorVersion
                    :GenericLogFunc, # log
                    :GenericLogFunc, # warn
                    :GenericLogFunc, # panic
                    :string,         # libDir
                    :string,         # configFile
                  ],
                  :VixError

  # This function is used to notify the host of the virtual machine that the
  # disks of the virtual machine will be opened.  The host disables operations on
  # the virtual machine that may be adversely affected if they are performed
  # while the disks are open by a third party application.
  #
  # @param connectParams [in] This is always used on remote connections.
  # @param identity [in] An arbitrary string containing the identity of the
  #           application.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :prepare_for_access, :VixDiskLib_PrepareForAccess,
                  [
                    ConnectParams, # connectParams,
                    :pointer       # identity
                  ],
                  :VixError
  # Get a list of transport modes known to VixDiskLib. This list is also the
  # default used if VixDiskLib_ConnectEx is called with transportModes set
  # to NULL.
  #
  # The string is a list of transport modes separated by colons. For
  # example: "file:san:hotadd:nbd". See VixDiskLib_ConnectEx for more details.
  #
  # @return Returns a string that is a list of plugins. The caller must not
  #         free the string.
  attach_function :list_transport_modes, :VixDiskLib_ListTransportModes,
                  [
                  ],
                  :pointer         # list of transport plugins

  # Opens a local or remote virtual disk.
  # @param connection [in] A valid connection.
  # @param path [in] VMDK file name given as absolute path
  #                        e.g. "[storage1] MailServer/SystemDisk.vmdk"
  # @param flags [in, optional] Bitwise or'ed  combination of
  #             VIXDISKLIB_FLAG_OPEN_UNBUFFERED
  #             VIXDISKLIB_FLAG_OPEN_SINGLE_LINK
  #             VIXDISKLIB_FLAG_OPEN_READ_ONLY.
  # @param diskHandle [out] Handle to opened disk, NULL if disk was not opened.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :open, :VixDiskLib_Open,
                  [
                    :Connection,   # connection
                    :pointer,      # path
                    :uint32,       # flags
                    :pointer       # disk handle
                  ],
                  :VixError

  # Reads a sector range.
  # @param diskHandle [in] Handle to an open virtual disk.
  # @param startSector [in] Absolute offset.
  # @param numSectors [in] Number of sectors to read.
  # @param readBuffer [out] Buffer to read into.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :read, :VixDiskLib_Read,
                  [
                    :pointer,      # disk handle
                    :SectorType,   # start sector
                    :SectorType,   # number of sectors
                    :pointer       # read buffer
                  ],
                  :VixError

  # Writes a sector range.
  # @param diskHandle [in] Handle to an open virtual disk.
  # @param startSector [in] Absolute offset.
  # @param numSectors [in] Number of sectors to write.
  # @param writeBuffer [in] Buffer to write.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :write, :VixDiskLib_Write,
                  [
                    :pointer,      # disk handle
                    :SectorType,   # start sector
                    :SectorType,   # number of sectors
                    :pointer       # write buffer
                  ],
                  :VixError

  # Retrieves the value of a metadata entry corresponding to the supplied key.
  # @param diskHandle [in] Handle to an open virtual disk.
  # @param key [in] Key name.
  # @param buf [out, optional] Placeholder for key's value in the metadata store,
  #            can be NULL.
  # @param bufLen [in] Size of the buffer.
  # @param requiredLen [out, optional] Size of buffer required for the value (including
  #                end of string character)
  # @return VIX_OK if success, VIX_E_DISK_BUFFER_TOO_SMALL if too small a buffer
  #             and other errors as applicable.
  attach_function :read_metadata, :VixDiskLib_ReadMetadata,
                  [
                    :pointer,     # diskHandle,
                    :pointer,     # key,
                    :pointer,     # buf,
                    :uint64,      # size_t bufLen,
                    :pointer,     # size_t *requiredLen
                  ],
                  :VixError

  # Creates or modifies a metadata table entry.
  # @param diskHandle [in] Handle to an open virtual disk.
  # @param key [in] Key name.
  # @param val [in] Key's value.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :write_metadata, :VixDiskLib_WriteMetadata,
                  [
                    :pointer,     # diskHandle,
                    :pointer,     # key,
                    :pointer      # val
                  ],
                  :VixError

  # Deletes all extents of the specified disk link. If the path refers to a
  # parent disk, the child (redo log) will be orphaned.
  # Unlinking the child does not affect the parent.
  # @param connection [in] A valid connection.
  # @param path [in] Path to the disk to be deleted.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :unlink, :VixDiskLib_Unlink,
                  [
                    :Connection,                # connection,
                    :pointer                    # const char *path);
                  ],
                  :VixError

  # Grows an existing disk, only local disks are grown.
  # @pre The specified disk is not open.
  # @param connection [in] A valid connection.
  # @param path [in] Path to the disk to be grown.
  # @param capacity [in] Target size for the disk.
  # @param updateGeometry [in] Should vixDiskLib update the geometry?
  # @param progressFunc [in] Callback to report progress (called on the same thread).
  # @param progressCallbackData [in] Opaque pointer passed along with the percent
  #                   complete.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :grow, :VixDiskLib_Grow,
                  [
                    :Connection,                # connection,
                    :pointer,                   # path,
                    :SectorType,                # capacity,
                    :bool,                      # updateGeometry,
                    :ProgressFunc,              # progressFunc,
                    :pointer                    # progressCallbackData);
                  ],
                  :VixError
  # Shrinks an existing disk, only local disks are shrunk.
  # @param diskHandle [in] Handle to an open virtual disk.
  # @param progressFunc [in] Callback to report progress (called on the same thread).
  # @param progressCallbackData [in] Opaque pointer passed along with the percent
  #                   complete.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :shrink, :VixDiskLib_Shrink,
                  [
                    :pointer,                   # diskHandle,
                    :ProgressFunc,              # progressFunc,
                    :pointer                    # progressCallbackData);
                  ],
                  :VixError

  # Defragments an existing disk.
  # @param diskHandle [in] Handle to an open virtual disk.
  # @param progressFunc [in] Callback to report progress (called on the same thread).
  # @param progressCallbackData [in] Opaque pointer passed along with the percent
  #                   complete.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :defragment, :VixDiskLib_Defragment,
                  [
                    :pointer,                   # diskHandle,
                    :ProgressFunc,              # progressFunc,
                    :pointer                    # progressCallbackData);
                  ],
                  :VixError

  # Renames a virtual disk.
  # @param srcFileName [in] Virtual disk file to rename.
  # @param dstFileName [in] New name for the virtual disk.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :rename, :VixDiskLib_Rename,
                  [
                    :pointer,       # srcFileName,
                    :pointer        # dstFileName
                  ],
                  :VixError

  # Copies a disk with proper conversion.
  # @param dstConnection [in] A valid connection to access the destination disk.
  # @param dstPath [in] Absolute path for the (new) destination disk.
  # @param srcConnection [in] A valid connection to access the source disk.
  # @param srcPath [in] Absolute path for the source disk.
  # @param vixCreateParams [in] creationParameters (disktype, hardware type...).
  #                   If the destination is remote, createParams is currently
  #                   ignored and disk with default size and adapter type is
  #                   created.
  # @param progressFunc [in] Callback to report progress (called on the same thread).
  # @param progressCallbackData [in] Opaque pointer passed along with the percent
  #                   complete.
  # @param overWrite [in] TRUE if Clone should overwrite an existing file.
  # @return VIX_OK if success, suitable VIX error code otherwise (network errors like
  #                   file already exists
  #                   handshake failure, ...
  #                   are all combined into a generic connect message).
  attach_function :clone, :VixDiskLib_Clone,
                  [
                    :Connection,           # dstConnection,
                    :pointer,              # dstPath,
                    :Connection,           # srcConnection,
                    :pointer,              # srcPath,
                    CreateParams,          # createParams,
                    :ProgressFunc,         # progressFunc,
                    :pointer,              # progressCallbackData);
                    :bool                  # overWrite);
                  ],
                  :VixError
  # Retrieves information about a disk.
  # @param diskHandle [in] Handle to an open virtual disk.
  # @param info [out] Disk information filled up.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :getinfo, :VixDiskLib_GetInfo,
                  [
                    :pointer,      # disk handle
                    :pointer       # disk info
                  ],
                  :VixError

  # Frees memory allocated in VixDiskLib GetInfo
  # @param info [in] Disk information to be freed.
  attach_function :freeinfo, :VixDiskLib_FreeInfo,
                  [
                    :pointer,      # disk info to free
                  ],
                  :void

  # Return the details for the connection.
  # @param connection [in] A VixDiskLib connection.
  # @param connectParams [out] Details of the connection.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :get_connect_params, :VixDiskLib_GetConnectParams,
                  [
                    :pointer,       #  connection,
                    :pointer        #  connectParams
                  ],
                  :VixError

  # Free the connection details structure allocated during
  # VixDiskLib_GetConnectParams.
  # @param connectParams [out] Connection details to be free'ed.
  # @return None.
  attach_function :free_connect_params, :VixDiskLib_FreeConnectParams,
                  [
                    :pointer         # connectParams
                  ],
                  :void

  # Checks if the child disk chain can be attached to the parent disk cahin.
  # @param parent [in] Handle to the disk to be attached.
  # @param child [in] Handle to the disk to attach.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :is_attach_possible, :VixDiskLib_IsAttachPossible,
                  [
                    :pointer,         # parent,
                    :pointer          # child
                  ],
                  :VixError

  # Attaches the child disk chain to the parent disk chain. Parent handle is
  # invalid after attaching and child represents the combined disk chain.
  # @param parent [in] Handle to the disk to be attached.
  # @param child [in] Handle to the disk to attach.
  # @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :attach, :VixDiskLib_Attach,
                  [
                    :pointer,         # parent,
                    :pointer          # child
                  ],
                  :VixError

  # Compute the space (in bytes) required to copy a disk chain.
  # @param diskHandle [in] Handle to the disk to be copied.
  # @param cloneDiskType [in] Type of the (to be) newly created disk.
  #   If cloneDiskType is VIXDISKLIB_DISK_UNKNOWN, the source disk
  #   type is assumed.
  # @param spaceNeeded [out] Place holder for space needed in bytes.
# @return VIX_OK if success, suitable VIX error code otherwise.
  attach_function :space_needed_for_clone, :VixDiskLib_SpaceNeededForClone,
                  [
                    :pointer,         # diskHandle,
                    :int,             # cloneDiskType,
                    :pointer          # spaceNeeded);
                  ],
                  :VixError

  # Check a sparse disk for internal consistency.
  # @param filename [in] Path to disk to be checked.
  # @param repair [in] TRUE if repair should be attempted, false otherwise.
  # @return VIX_OK if success, suitable VIX error code otherwise.  Note
  #    this refers to the success of the call, not the consistency of
  #    the disk being checked.
  attach_function :check_repair, :VixDiskLib_CheckRepair,
                  [
                    :pointer,          # connection,
                    :pointer,          # filename,
                    :bool              # repair);
                  ],
                  :VixError
end
