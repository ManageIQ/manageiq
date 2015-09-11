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
end
