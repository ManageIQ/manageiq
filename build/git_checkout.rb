require 'pathname'

module Build
  class GitCheckout
    attr_reader :commit_sha, :branch_or_tag, :remote
    def initialize(remote)
      @remote = remote
      read_version_file
    end

    def commit_sha
      long_sha =
        if @branch_or_tag == "master"
          ls_remote_sha("master")
        else
          ls_remote_sha(dereferenced_tag) || ls_remote_sha(@branch_or_tag)
        end
      long_sha.to_s[0, 10]
    end

    def ls_remote_sha(target)
      `git ls-remote #{remote} #{target}`.split.first
    end

    private

    def dereferenced_tag
      "#{@branch_or_tag}^{}"
    end

    # TODO: Perhaps the contents of the VERSION should be passed in
    def read_version_file
      file = Pathname.new(File.expand_path(File.dirname(__FILE__)))
      @branch_or_tag = File.read(file.join("../vmdb/VERSION")).strip
    end
  end
end
