require_relative 'git_worktree_exception'

class GitWorktree
  attr_accessor :name, :email, :base_name
  ENTRY_KEYS = [:path, :dev, :ino, :mode, :gid, :uid, :ctime, :mtime]
  DEFAULT_FILE_MODE = 0100644
  LOCK_REFERENCE = 'refs/locks'

  def self.checkout_at(url, directory, options = {})
    worktree_opts = options.merge(
      :path  => directory,
      :url   => url,
      :clone => true,
      :bare  => false
    )
    GitWorktree.new(worktree_opts).checkout
  end

  def initialize(options = {})
    require 'rugged'

    raise ArgumentError, "Must specify path" unless options.key?(:path)

    @path                 = options[:path]
    @email                = options[:email]
    @username             = options[:username]
    @bare                 = options[:bare]
    @commit_sha           = options[:commit_sha]
    @password             = options[:password]
    @ssh_private_key      = options[:ssh_private_key]
    @fast_forward_merge   = options[:ff] || true
    @proxy_url            = options[:proxy_url]
    @certificate_check_cb = options[:certificate_check]

    @options              = options.dup

    @remote_name = 'origin'
    @base_name   = File.basename(@path)

    # The libssh2 library must already be installed at gem installation time
    # for the 'ssh' feature to be available.
    #
    # For Fedora/Centos, the presence of libssh2 seems to be enough to get it
    # to build properly.
    #
    # For OSX:
    #
    #     $ brew install libssh2
    #     $ gem uninstall rugged  # if required
    #     $ export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/usr/local/opt/openssl/lib/pkgconfig"
    #     $ bin/bundle
    #
    if @ssh_private_key && !Rugged.features.include?(:ssh)
      raise GitWorktreeException::InvalidCredentialType, "ssh credentials are not enabled for use. Recompile the rugged/libgit2 gem with ssh support to enable it."
    end

    process_repo(options)
  end

  def delete_repo
    return false unless @repo
    @repo.close
    FileUtils.rm_rf(@path)
    true
  end

  def branches(where = nil)
    where.nil? ? @repo.branches.each_name.sort : @repo.branches.each_name(where).sort
  end

  private def find_branch(name)
    @repo.branches.each.detect do |b|
      b.name.casecmp(name) == 0 || b.name.casecmp("#{@remote_name}/#{name}") == 0
    end
  end

  def branch=(name)
    branch = find_branch(name)
    raise GitWorktreeException::BranchMissing, name unless branch
    @commit_sha = branch.target.oid
  end

  def branch_info(name)
    branch = find_branch(name)
    raise GitWorktreeException::BranchMissing, name unless branch
    {:time => branch.target.time, :message => branch.target.message, :commit_sha => branch.target.oid}
  end

  def tags
    @repo.tags.each.collect(&:name)
  end

  private def find_tag(name)
    @repo.tags.each.detect { |t| t.name.casecmp(name) == 0 }
  end

  def tag=(name)
    tag = find_tag(name)
    raise GitWorktreeException::TagMissing, name unless tag
    @commit_sha = tag.target.oid
  end

  def tag_info(name)
    tag = find_tag(name)
    raise GitWorktreeException::TagMissing, name unless tag
    {:time => tag.target.time, :message => tag.target.message, :commit_sha => tag.target.oid}
  end

  private def find_ref(ref)
    @repo.lookup(ref)
  rescue Rugged::InvalidError, Rugged::OdbError
    nil
  end

  def ref=(ref)
    if find_branch(ref)
      self.branch = ref
    elsif find_tag(ref)
      self.tag = ref
    elsif find_ref(ref)
      @commit_sha = @repo.lookup(ref).oid
    else
      raise GitWorktreeException::RefMissing, ref
    end
  end

  def add(path, data, default_entry_keys = {})
    entry = {}
    entry[:path] = path
    ENTRY_KEYS.each { |key| entry[key] = default_entry_keys[key] if default_entry_keys.key?(key) }
    entry[:oid]  = @repo.write(data, :blob)
    entry[:mode] ||= DEFAULT_FILE_MODE
    entry[:mtime] ||= Time.now
    current_index.add(entry)
  end

  def remove(path)
    current_index.remove(path)
  end

  def remove_dir(path)
    current_index.remove_dir(path)
  end

  def file_exists?(path)
    !!find_entry(path)
  end

  def directory_exists?(path)
    entry = find_entry(path)
    entry && entry[:type] == :tree
  end

  def read_file(path)
    read_entry(fetch_entry(path))
  end

  def read_entry(entry)
    @repo.lookup(entry[:oid]).content
  end

  def entries(path)
    tree = get_tree(path)
    tree.find_all.collect { |e| e[:name] }
  end

  def nodes(path)
    tree = path.empty? ? lookup_commit_tree : get_tree(path)
    entries = tree.find_all
    entries.each do |entry|
      entry[:full_name] = File.join(@base_name, path, entry[:name])
      entry[:rel_path] = File.join(path, entry[:name])
    end
  end

  def save_changes(message, owner = :local)
    cid = commit(message)
    if owner == :local
      lock { merge(cid) }
    else
      merge_and_push(cid)
    end
    true
  end

  def file_attributes(fname)
    walker = Rugged::Walker.new(@repo)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(@repo.ref(local_ref).target)
    commit = walker.find { |c| c.diff(:paths => [fname]).size > 0 }
    return {} unless commit
    {:updated_on => commit.time.gmtime, :updated_by => commit.author[:name]}
  end

  def file_list
    tree = lookup_commit_tree
    return [] unless tree
    tree.walk(:preorder).collect { |root, entry| "#{root}#{entry[:name]}" }
  end

  # Like "file_list", but doesn't return directories
  def blob_list
    tree = lookup_commit_tree
    return [] unless tree

    [].tap do |blobs|
      tree.walk_blobs(:preorder) { |root, entry| blobs << "#{root}#{entry[:name]}" }
    end
  end

  def find_entry(path)
    get_tree_entry(path)
  end

  def mv_file_with_new_contents(old_file, new_path, new_data, default_entry_keys = {})
    add(new_path, new_data, default_entry_keys)
    remove(old_file)
  end

  def mv_file(old_file, new_file)
    entry = current_index[old_file]
    return unless entry
    entry[:path] = new_file
    current_index.add(entry)
    remove(old_file)
  end

  def mv_dir(old_dir, new_dir)
    raise GitWorktreeException::DirectoryAlreadyExists, new_dir if find_entry(new_dir)
    old_dir = fix_path_mv(old_dir)
    new_dir = fix_path_mv(new_dir)
    updates = current_index.entries.select { |entry| entry[:path].start_with?(old_dir) }
    updates.each do |entry|
      entry[:path] = entry[:path].sub(old_dir, new_dir)
      current_index.add(entry)
    end
    current_index.remove_dir(old_dir)
  end

  def checkout_to(target_directory)
    tree = lookup_commit_tree
    @repo.checkout_tree(tree, :target_directory => target_directory, :strategy => :force)
  end

  def checkout_at(target_directory)
    checkout_to(target_directory)
  rescue Rugged::SubmoduleError
    FileUtils.rm_rf(target_directory) # cleanup from failed checkout above
    GitWorktree.checkout_at(@path, target_directory, @options.merge(:commit_sha => @commit_sha))
  end

  def checkout
    @repo.checkout(@commit_sha || current_branch, :strategy => :force)
    @repo.submodules.each do |submodule|
      submodule.init
      module_path = File.expand_path(submodule.path, @path)
      GitWorktree.checkout_at(submodule.url, module_path, @options.merge(:commit_sha => submodule.head_oid))
    end
  end

  def with_remote_options
    if @ssh_private_key
      @ssh_private_key_file = Tempfile.new
      @ssh_private_key_file.write(@ssh_private_key)
      @ssh_private_key_file.close
    end

    options = {:credentials => method(:credentials_cb), :proxy_url => @proxy_url}
    options[:certificate_check] = @certificate_check_cb if @certificate_check_cb

    yield options
  ensure
    if @ssh_private_key_file
      @ssh_private_key_file.unlink
      @ssh_private_key_file = nil
    end
  end

  private

  def credentials_cb(url, username_from_url, _allowed_types)
    username = @username || username_from_url

    if @ssh_private_key_file
      raise GitWorktreeException::InvalidCredentials, "Please provide username for URL #{url}" if username.blank?

      Rugged::Credentials::SshKey.new(
        :username   => username,
        :privatekey => @ssh_private_key_file.path,
        :passphrase => @password.presence
      )
    else
      raise GitWorktreeException::InvalidCredentials, "Please provide username and password for URL #{url}" if @username.blank? || @password.blank?

      Rugged::Credentials::UserPassword.new(
        :username => @username,
        :password => @password
      )
    end
  end

  def current_branch
    @repo.head_unborn? ? 'master' : @repo.head.name.sub(/^refs\/heads\//, '')
  end

  def upstream_ref
    "refs/remotes/#{@remote_name}/#{current_branch}"
  end

  def local_ref
    "refs/heads/#{current_branch}"
  end

  def fetch_and_merge
    fetch
    commit = @repo.ref(upstream_ref).target
    merge(commit)
  end

  def fetch
    with_remote_options do |remote_options|
      @repo.fetch(@remote_name, remote_options)
    end
  end

  def pull
    lock { fetch_and_merge }
  end

  def merge_and_push(commit)
    rebase = false
    push_lock do
      @saved_cid = @repo.ref(local_ref).target.oid
      merge(commit, rebase)
      rebase = true
      with_remote_options do |remote_options|
        @repo.push(@remote_name, [local_ref], remote_options)
      end
    end
  end

  def merge(commit, rebase = false)
    current_branch = @repo.ref(local_ref)
    merge_index = @repo.merge_commits(current_branch.target, commit) if current_branch
    if merge_index && merge_index.conflicts?
      result = differences_with_current(commit)
      raise GitWorktreeException::GitConflicts, result
    end
    commit = rebase(commit, merge_index, current_branch.try(:target)) if rebase
    @repo.reset(commit, :soft)
  end

  def rebase(commit, merge_index, parent)
    commit_obj = commit if commit.class == Rugged::Commit
    commit_obj ||= @repo.lookup(commit)
    Rugged::Commit.create(@repo, :author    => commit_obj.author,
                                 :committer => commit_obj.author,
                                 :message   => commit_obj.message,
                                 :parents   => parent ? [parent] : [],
                                 :tree      => merge_index.write_tree(@repo))
  end

  def commit(message)
    tree = @current_index.write_tree(@repo)
    parents = @repo.empty? ? [] : [@repo.ref(local_ref).target].compact
    create_commit(message, tree, parents)
  end

  def process_repo(options)
    if options[:url]
      clone(options[:url], options.key?(:bare) ? options[:bare] : true)
    elsif options[:new]
      create_repo
    else
      open_repo
    end
  end

  def create_repo
    @repo = @bare ? Rugged::Repository.init_at(@path, :bare) : Rugged::Repository.init_at(@path)
    @repo.config['user.name']  = @username  if @username
    @repo.config['user.email'] = @email if @email
    @repo.config['merge.ff']   = 'only' if @fast_forward_merge
  end

  def open_repo
    @repo = Rugged::Repository.new(@path)
  end

  def clone(url, bare = true)
    @repo = with_remote_options do |remote_options|
      options = remote_options.merge(:bare => bare, :remote => @remote_name)
      Rugged::Repository.clone_at(url, @path, options)
    end
  end

  def fetch_entry(path)
    find_entry(path).tap do |entry|
      raise GitWorktreeException::GitEntryMissing, path unless entry
    end
  end

  def fix_path_mv(dir_name)
    dir_name = dir_name[1..-1] if dir_name[0] == '/'
    dir_name += '/'            if dir_name[-1] != '/'
    dir_name
  end

  def get_tree(path)
    return lookup_commit_tree if path.empty?
    entry = get_tree_entry(path)
    raise GitWorktreeException::GitEntryMissing, path unless entry
    raise GitWorktreeException::GitEntryNotADirectory, path  unless entry[:type] == :tree
    @repo.lookup(entry[:oid])
  end

  def lookup_commit_tree
    return nil if !@commit_sha && !@repo.branches['master']
    ct = @commit_sha ? @repo.lookup(@commit_sha) : @repo.branches['master'].target
    ct.tree if ct
  end

  def get_tree_entry(path)
    path = path[1..-1] if path[0] == '/'
    tree = lookup_commit_tree
    begin
      entry             = tree.path(path)
      entry[:full_name] = File.join(@base_name, path)
      entry[:rel_path]  = path
    rescue
      return nil
    end
    entry
  end

  def current_index
    @current_index ||= Rugged::Index.new.tap do |index|
      unless @repo.empty?
        tree = lookup_commit_tree
        raise ArgumentError, "Cannot locate commit tree" unless tree
        @current_tree_oid = tree.oid
        index.read_tree(tree)
      end
    end
  end

  def create_commit(message, tree, parents)
    author = {:email => @email, :name => @username || @email, :time => Time.now}
    # Create the actual commit but dont update the reference
    Rugged::Commit.create(@repo, :author  => author,  :committer  => author,
                                 :message => message, :parents    => parents,
                                 :tree    => tree)
  end

  def lock
    @repo.references.create(LOCK_REFERENCE, local_ref)
    yield
  rescue Rugged::ReferenceError
    sleep 0.1
    retry
  ensure
    @repo.references.delete(LOCK_REFERENCE)
  end

  def push_lock
    @repo.references.create(LOCK_REFERENCE, local_ref)
    begin
      yield
    rescue Rugged::ReferenceError => err
      sleep 0.1
      @repo.reset(@saved_cid, :soft)
      fetch_and_merge
      retry
    rescue GitWorktreeException::GitConflicts => err
      @repo.reset(@saved_cid, :soft)
      raise GitWorktreeException::GitConflicts, err.conflicts
    ensure
      @repo.references.delete(LOCK_REFERENCE)
    end
  end

  def differences_with_current(commit)
    differences = {}
    diffs = @repo.diff(commit, @repo.ref(local_ref).target)
    diffs.deltas.each do |delta|
      result = []
      delta.diff.each_line do |line|
        next unless line.addition? || line.deletion?
        result << "+ #{line.content.to_str}"  if line.addition?
        result << "- #{line.content.to_str}"  if line.deletion?
      end
      differences[delta.old_file[:path]] = {:status => delta.status, :diffs => result}
    end
    differences
  end
end
