require "rugged"

class GitRepository < ApplicationRecord
  include AuthenticationMixin
  belongs_to :authentication

  GIT_REPO_DIRECTORY = Rails.root.join('data/git_repos')
  LOCKFILE_DIR       = GIT_REPO_DIRECTORY.join("locks")

  attr_reader :git_lock

  validates :url, :format => Regexp.union(URI.regexp(%w[http https file ssh]), /\A[-\w:.]+@.*:/), :allow_nil => false

  default_value_for :verify_ssl, OpenSSL::SSL::VERIFY_PEER
  validates :verify_ssl, :inclusion => {:in => [OpenSSL::SSL::VERIFY_NONE, OpenSSL::SSL::VERIFY_PEER]}

  has_many :git_branches, :dependent => :destroy
  has_many :git_tags, :dependent => :destroy
  after_destroy :broadcast_repo_dir_delete

  INFO_KEYS = %w(commit_sha commit_message commit_time name).freeze

  def self.delete_repo_dir(id, directory_name)
    _log.info("Deleting GitRepository[#{id}] in #{directory_name} for MiqServer[#{MiqServer.my_server.id}]...")
    FileUtils.rm_rf(directory_name)
  end

  # Ping the git repository endpoint to verify that the network connection is still up.
  # We use this approach for now over Rugged#check_connection because of a segfault:
  #
  #   https://github.com/libgit2/rugged/issues/859
  #
  def check_connection?
    require 'net/ping/external'

    # URI library cannot handle git urls, so just convert it to a standard url.
    temp_url = url.dup.to_s
    temp_url = temp_url.sub(':', '/').sub('git@', 'https://') if temp_url.start_with?('git@')

    host = URI.parse(temp_url).hostname

    $log.debug("pinging '#{host}' to verify network connection")
    ext_ping = Net::Ping::External.new(host)

    result = ext_ping.ping?
    $log.debug("ping failed: #{ext_ping.exception}") unless result

    result
  end

  def refresh
    update_repo
    transaction do
      refresh_branches
      refresh_tags
      self.last_refresh_on = Time.now.utc
      save!
    end
  end

  def branch_info(name)
    ensure_refreshed
    branch = git_branches.detect { |item| item.name == name }
    raise "Branch #{name} not found" unless branch
    branch.attributes.slice(*INFO_KEYS)
  end

  def tag_info(name)
    ensure_refreshed
    tag = git_tags.detect { |item| item.name == name }
    raise "Tag #{name} not found" unless tag
    tag.attributes.slice(*INFO_KEYS)
  end

  def entries(ref, path)
    ensure_refreshed
    with_worktree do |worktree|
      worktree.ref = ref
      worktree.entries(path)
    end
  end

  def checkout(ref, path)
    ensure_refreshed
    with_worktree do |worktree|
      message = "Checking out #{url}@#{ref} to #{path}..."
      _log.info(message)
      worktree.ref = ref
      worktree.checkout_at(path)
      _log.info("#{message}...Complete")
    end
    path
  end

  def directory_name
    raise ActiveRecord::RecordNotSaved if new_record?

    File.join(GIT_REPO_DIRECTORY, id.to_s)
  end

  def self_signed_cert_cb(_valid, _host)
    true
  end

  def with_worktree
    handling_worktree_errors do
      yield worktree
    end
  end

  def update_repo
    with_worktree do |worktree|
      message = "Updating #{url} in #{directory_name}..."
      _log.info(message)
      worktree.send(:pull)
      _log.info("#{message}...Complete")
    end
    @updated_repo = true
  end

  # Configures a file lock in LOCKFILE_DIR so that only a single process has
  # access to make changes to the `GitWorktree` at a time.  Assumes the record
  # has been saved, since there is no way store (clone, fetch, pull, etc.) the
  # git data to disk if there isn't a `id`.
  #
  # Only a single `@git_lock` can be acquired per-process, and do avoid
  # deadlocks, this method is just a passthrough if `@git_lock` has already been
  # defined (another method has already started a `git_transaction`.)
  #
  # This means that you can surround a couple of actions with this method, and
  # the lock will only be enforced on the top level.
  #
  # NOTE: However, it is worth noting that if two threads in the same process
  # try to share the same instance while using `git_transaction` is not thread
  # safe, so avoid sharing `GitRepository` objects across multiple threads
  # (chances are you won't run into this scenario, but commenting just in case)
  #
  # Return value is the result of the yielded block
  def git_transaction
    should_unlock = acquire_git_lock
    yield
  ensure
    release_git_lock if should_unlock
  end

  private

  def ensure_refreshed
    refresh unless @updated_repo
  end

  def refresh_branches
    with_worktree do |worktree|
      current_branches = git_branches.index_by(&:name)
      worktree.branches(:remote).each do |branch|
        info = worktree.branch_info(branch)
        attrs = {:name           => branch,
                 :commit_sha     => info[:commit_sha],
                 :commit_time    => info[:time],
                 :commit_message => info[:message]}

        stored_branch = current_branches.delete(branch)
        stored_branch ? stored_branch.update!(attrs) : git_branches.create!(attrs)
      end
      git_branches.delete(current_branches.values)
    end
  end

  def refresh_tags
    with_worktree do |worktree|
      current_tags = git_tags.index_by(&:name)
      worktree.tags.each do |tag|
        info = worktree.tag_info(tag)
        attrs = {:name           => tag,
                 :commit_sha     => info[:commit_sha],
                 :commit_time    => info[:time],
                 :commit_message => info[:message]}

        stored_tag = current_tags.delete(tag)
        stored_tag ? stored_tag.update(attrs) : git_tags.create!(attrs)
      end
      git_tags.delete(current_tags.values)
    end
  end

  def worktree
    @worktree ||= begin
      clone_repo_if_missing
      fetch_worktree
    end
  end

  def fetch_worktree
    GitWorktree.new(worktree_params)
  end

  def clone_repo_if_missing
    git_transaction do
      unless Dir.exist?(directory_name)
        handling_worktree_errors do
          message = "Cloning #{url} to #{directory_name}..."
          _log.info(message)
          GitWorktree.new(worktree_params.merge(:clone => true, :url => url))
          @updated_repo = true
          _log.info("#{message}...Complete")
        end
      end
    end
  end

  def handling_worktree_errors
    yield
  rescue ::Rugged::NetworkError => err
    raise MiqException::MiqUnreachableError, err.message
  rescue => err
    raise MiqException::Error, err.message
  end

  def git_lock_filename
    @git_lock_filename ||= LOCKFILE_DIR.join(id.to_s)
  end

  def acquire_git_lock
    return false if git_lock

    FileUtils.mkdir_p(LOCKFILE_DIR)

    @git_lock = File.open(git_lock_filename, File::RDWR | File::CREAT, 0o644)
    @git_lock.flock(File::LOCK_EX)                         # block waiting for lock
    @git_lock.write("#{Process.pid} - #{Time.zone.now}\n") # for debugging
    @git_lock.flush                                        # write current data
    @git_lock.truncate(@git_lock.pos)                      # clean up remaining chars

    true
  end

  def release_git_lock
    return if git_lock.nil?

    @git_lock.flock(File::LOCK_UN)
    @git_lock.close
    @git_lock = nil
  end

  def worktree_params
    params = {:path => directory_name}
    params[:certificate_check] = method(:self_signed_cert_cb) if verify_ssl == OpenSSL::SSL::VERIFY_NONE
    if (auth = authentication || default_authentication)
      params[:username] = auth.userid
      if auth.auth_key
        params[:ssh_private_key] = auth.auth_key
        params[:password] = auth.auth_key_password.presence
      else
        params[:password] = auth.password
      end
    end
    params[:proxy_url] = proxy_url if proxy_url?
    params
  end

  def proxy_url?
    return false unless !!Settings.git_repository_proxy.host
    return false unless %w[http https].include?(Settings.git_repository_proxy.scheme)

    repo_url_scheme = begin
                        URI.parse(url).scheme
                      rescue URI::InvalidURIError
                        # url is not a parsable URI, such as git@github.com:ManageIQ/manageiq.git
                        nil
                      end
    %w[http https].include?(repo_url_scheme)
  end

  def proxy_url
    uri_opts = Settings.git_repository_proxy.to_h.slice(:host, :port, :scheme, :path)
    uri_opts[:path] ||= "/"
    URI::Generic.build(uri_opts).to_s
  end

  def broadcast_repo_dir_delete
    MiqQueue.broadcast(
      :class_name  => self.class.name,
      :method_name => "delete_repo_dir",
      :args        => [id, directory_name]
    )
  end
end
