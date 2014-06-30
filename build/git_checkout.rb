require 'pathname'

module Build
  class GitCheckout
    attr_reader :commit_sha, :remote
    def initialize(remote)
      @remote = remote
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

    # TODO: Perhaps the contents of the VERSION should be passed in
    def ref
      @ref ||= begin
        file = Pathname.new(File.expand_path(File.dirname(__FILE__)))
        File.read(file.join("../vmdb/VERSION")).strip
      end
    end
  end
end
