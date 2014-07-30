require 'ffi'

module FFI
  module VixDiskLib
    module API
      extend FFI::Library

      def attach_function(*args)
        super
      rescue FFI::NotFoundError
        warn "unable to attach #{args.first}"
      end

      #
      # Make sure we load one and only one version of VixDiskLib
      #
      version_load_order = %w( 5.5.2 5.5.1 5.5.0 5.1.3 5.1.2 5.1.1 5.1.0 5.0.4 5.0.0 1.2.0 1.1.2 )
      bad_versions       = {"5.1.0" => "Disk Open May Core Dump without an SSL Thumbprint"}
      load_errors        = []
      loaded_library     = ""
      version_load_order.each do |version|
        begin
          loaded_library = ffi_lib ["vixDiskLib.so.#{version}"]
          VERSION_MAJOR, VERSION_MINOR = loaded_library.first.name.split(".")[2, 2].collect(&:to_i)
          if bad_versions.keys.include?(version)
            loaded_library = ""
            raise LoadError, "VixDiskLib #{version} is not supported: #{bad_versions[version]}"
          end
          break
        rescue LoadError => err
          load_errors << "ffi-vixdisklib: failed to load #{version} version with error: #{err.message}."
          next
        end
      end

      unless loaded_library.length > 0
        STDERR.puts load_errors.join("\n")
        raise LoadError, "ffi-vixdisklib: failed to load any version of VixDiskLib!"
      end
      LOADED_LIBRARY = loaded_library

      # An error is a 64-bit value. If there is no error, then the value is
      # set to VIX_OK. If there is an error, then the least significant bits
      # will be set to one of the integer error codes defined below. The more
      # significant bits may or may not be set to various values, depending on
      # the errors.

      def self.vix_error_code(err)
        err & 0xFFFF
      end

      def self.vix_succeeded?(err)
        err == VixErrorType[:VIX_OK]
      end

      def self.vix_failed?(err)
        err != VixErrorType[:VIX_OK]
      end

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
                        :pointer                    # const char *path
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
                        :pointer                    # progressCallbackData
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
                        :pointer                    # progressCallbackData
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
                        :pointer                    # progressCallbackData
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
                        :pointer,              # progressCallbackData
                        :bool                  # overWrite
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
                        :pointer          # spaceNeeded
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
                        :bool              # repair
                      ],
                      :VixError
    end
  end
end
