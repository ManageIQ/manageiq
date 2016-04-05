# NOTE: If included, this must be included AFTER any autoloaded modules since it
#       modifies included.name.  Rails autoload will not be able to detect
#       the other modules if included before them.
#

module MigrationStubHelper
  extend ActiveSupport::Concern
  included do
    # Fixes issues where reflections in stubs will use the class name in the
    #   query, which is unexpectedly namespaced.
    def self.name
      super.split("::")[1..-1].join("::")
    end
  end
end
