module MiqException
  # Abstract MIQ Error Class
  class Error < RuntimeError; end

  class MiqTimeoutError < Error; end

  class MiqCommunicationsError < Error; end
  class MiqConnectionRefusedError < MiqCommunicationsError; end
  class MiqCommunicationsTimeoutError < MiqCommunicationsError; end

  # MiqQueue Exceptions
  class MiqQueueError         < Error; end
  class MiqQueueRetryLater    < MiqQueueError
    attr :options
    def initialize(options = {})
      @options = options
    end
  end
  class MiqQueueExpired       < MiqQueueError; end

  # Concrete MIQ Policy Action Errors/Exceptions based on abstract Error class above
  class MiqActionError        < Error; end
  class StopAction            < MiqActionError; end
  class AbortAction           < MiqActionError; end
  class UnknownActionRc       < MiqActionError; end
  class PolicyPreventAction   < MiqActionError; end

  # Login/Logout user related errors
  class MiqEVMLoginError         < Error; end
  class MiqHostError             < Error; end
  class MiqInvalidCredentialsError < Error; end
  class MiqUnreachableError      < Error; end
  class MiqVmError               < Error; end
  class MiqVmSnapshotError       < MiqVmError; end
  class MiqVmNotConnectedError   < MiqVmError; end
  class MiqVmMountError          < MiqVmError; end

  class MiqStorageError          < Error; end
  class MiqUnsupportedStorage    < MiqStorageError; end
  class MiqUnreachableStorage    < MiqStorageError; end

  # Exceptions during Provisioning
  class MiqProvisionError        < Error; end

  class MiqVimError              < Error; end
  class MiqVimBrokerStaleHandle  < MiqVimError; end
  class MiqVimBrokerUnavailable  < MiqVimError; end
  class MiqVimSessionKilledError < MiqVimError; end
  class MiqVimConnRefusedError   < MiqVimError; end
  class MiqVimSocketError        < MiqVimError; end
  class MiqVimInvalidParameter   < MiqVimError; end
  class MiqVimSoapFault          < MiqVimError; end
  class MiqVimCacheLockNotHeld   < MiqVimError; end
  class MiqVimInvalidState       < MiqVimError; end
  class MiqVimNotSupported       < MiqVimError; end
  class MiqVimShutdown           < MiqVimError; end
  # MiqVimResourceNotFound is derived from RuntimeError to ensure it gets marshalled over DRB properly.
  # TODO: Rename MiqException::Error class to avoid issues returning derived error classes over DRB.
  #       Then change MiqVimResourceNotFound to derive from MiqVimError
  class MiqVimResourceNotFound   < RuntimeError; end

  class MaintenanceBundleInvalid < Error; end
  class MiqDeploymentError       < Error; end

  class RemoteConsoleNotSupportedError < Error; end
  class InvalidRufusArgument < Error; end

  class MiqServiceError < Error; end
  class MiqServiceCircularReferenceError < MiqServiceError; end

  # VM scanning errors
  class NtEventLogFormat         < Error; end

  # EMS Refresh errors
  class MiqIncompleteData        < Error
    def initialize(msg="Incomplete data from EMS")
      super
    end
  end

  # Openstack connection error when service is not available
  class ServiceNotAvailable < Error; end

  # MiqGenericMountSession Errors
  class MountPointAlreadyExists         < Error; end
  class MiqLogFileMountPointMissing     < Error; end
  class MiqLogFileNoSuchFileOrDirectory < Error; end

  class MiqDatabaseBackupInsufficientSpace < Error; end

  class RbacPrivilegeException < Error; end
end
