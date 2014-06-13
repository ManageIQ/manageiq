require 'drb'

module MiqAeException
  # Abstract MIQ Automation Engine (MiqAE) Error Class
  class Error < RuntimeError
    include DRbUndumped
  end

  # Concrete MIQ Automation Engine (MiqAE) Errors/Exceptions based on abstract Error class above
  class MiqAeEngineError  < Error; end
    class AssertionFailure     < MiqAeEngineError; end
    class CyclicalRelationship < MiqAeEngineError; end
    class ServiceNotFound      < MiqAeEngineError; end
    class StopInstantiation    < MiqAeEngineError; end
    class AbortInstantiation   < MiqAeEngineError; end
    class UnknownMethodRc      < MiqAeEngineError; end
    class ObjectNotFound       < MiqAeEngineError; end
    class InvalidPathFormat    < MiqAeEngineError; end
    class InvalidCollection    < MiqAeEngineError; end
    class InvalidMethod        < MiqAeEngineError; end
    class MethodNotFound       < MiqAeEngineError; end
    class MethodParmMissing    < MiqAeEngineError; end
    class WorkspaceNotFound    < MiqAeEngineError; end

  class MiqAeDatastoreError < Error; end
    class DomainNotFound       < MiqAeDatastoreError; end
    class NamespaceNotFound    < MiqAeDatastoreError; end
    class ClassNotFound        < MiqAeDatastoreError; end
    class InstanceNotFound     < MiqAeDatastoreError; end
    class FieldNotFound        < MiqAeDatastoreError; end
    class InvalidClass         < MiqAeDatastoreError; end
    class InvalidDomain        < MiqAeDatastoreError; end
    class DirectoryNotFound    < MiqAeDatastoreError; end
    class FileNotFound         < MiqAeDatastoreError; end
    class DirectoryExists      < MiqAeDatastoreError; end
    class FileExists           < MiqAeDatastoreError; end
end

module MiqException
  # Abstract MIQ Error Class
  class Error < RuntimeError
    include DRbUndumped
  end
end
