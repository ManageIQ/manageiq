module GitWorktreeException
  class GitConflicts < RuntimeError
    attr_reader :conflicts
    def initialize(conflicts)
      @conflicts = conflicts
      super
    end
  end

  class GitEntryMissing < RuntimeError; end
  class GitRepositoryMissing < RuntimeError; end
  class DirectoryAlreadyExists < RuntimeError; end
  class BranchMissing < RuntimeError; end
  class TagMissing < RuntimeError; end
  class RefMissing < RuntimeError; end
  class InvalidCredentials < RuntimeError; end
  class InvalidCredentialType < RuntimeError; end
end
