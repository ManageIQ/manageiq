require 'pathname'

module Build
  class GitCheckout
    attr_reader :commit_sha, :remote, :ref

    def initialize(options)
      @remote = options[:remote]
      @ref    = options[:ref]
    end

    def commit_sha
      long_sha =
        if ref == "master"
          ls_remote_sha("master")
        else
          ls_remote_sha(dereferenced_tag) || ls_remote_sha(ref)
        end
      long_sha.to_s[0, 10]
    end

    def branch
      ref.split("-").first
    end

    def ls_remote_sha(target)
      `git ls-remote #{remote} #{target}`.split.first
    end

    private

    def dereferenced_tag
      "#{ref}^{}"
    end
  end
end
