module MiqAeFsStore
  DOMAIN_YAML_FILE    = '__domain__.yaml'
  NAMESPACE_YAML_FILE = '__namespace__.yaml'
  CLASS_YAML_FILE     = '__class__.yaml'
  METHODS_DIRECTORY   = '__methods__'
  CLASS_DIR_SUFFIX    = '.class'
  OBJ_YAML_VERSION    = '1.0'
  DOMAIN_OBJ_TYPE     = 'domain'
  NAMESPACE_OBJ_TYPE  = 'namespace'
  CLASS_OBJ_TYPE      = 'class'
  INSTANCE_OBJ_TYPE   = 'instance'
  METHOD_OBJ_TYPE     = 'method'
  CLASS_SCOPE_PREFIX  = "$class$"
  ID_DELIMITER        = "!"
  GIT_DIR_EXTENSION   = ".git"
  GIT_OPTIONS         = {:email => "user@sample.com", :name => 'user1', :bare => true}
  DEFAULT_GIT_USER    = "admin"
  DEFAULT_GIT_EMAIL   = "admin@example.com"

  extend ActiveSupport::Concern

  module ClassMethods
    def exists?(fqname)
      git_entry_exists?(fqname.downcase)
    end

    def id_to_fqname(id)
      id.class == String ? id.gsub(ID_DELIMITER, '/') : nil
    end

    def fqname_to_id(fqname)
      fqname.gsub('/', ID_DELIMITER)
    end

    def strip_domain(filename)
      filename.split('/')[2..-1].join('/')
    end

    def relative_filename(dirname, filename)
      File.join(strip_domain(dirname), filename).downcase
    end

    def load_yaml_file(filename, git_repo = nil)
      YAML.load(read_file(filename, git_repo))
    end

    def read_file(filename, git_repo = nil)
      domain, fname = split_path(filename)
      git_repo ||= git_repository(domain)
      raise MiqException::MiqGitRepositoryMissing unless git_repo
      git_repo.read_file(fname)
    end

    def fs_name(path, create = false)
      domain, fname = split_path(path)
      git_repo = git_repository(domain, create)
      return nil unless git_repo
      return path if fname == ""
      git_repo.file_exists?(fname) ? path : nil
    end

    def file_exists?(path, git_repo = nil)
      domain, fname = split_path(path)
      git_repo ||= git_repository(domain)
      return false unless git_repo
      return true if fname == ""
      git_repo.file_exists?(fname)
    end

    def git_repo_fqname(fqname)
      domain, path = split_path(fqname)
      git_repo = git_repository(domain)
      return git_repo, path
    end

    def split_path(path)
      path   = path[1..-1] if path[0] == '/'
      parts  = path.split('/')
      domain = parts.shift
      return domain, parts.join('/')
    end

    def git_repository(domain, create = false)
      domain_dir_name = domain_dir(domain)
      if domain_dir_name
        domain_dir = File.join(MiqAeDatastore::DATASTORE_DIRECTORY, domain_dir_name)
        git_repo = MiqAeGit.new(:path => domain_dir)
      else
        return nil unless create
        domain_dir = File.join(MiqAeDatastore::DATASTORE_DIRECTORY, domain)
        name = User.current_user ? User.current_user.name : DEFAULT_GIT_USER
        email = User.current_user ? User.current_user.email : nil
        email ||= DEFAULT_GIT_EMAIL
        git_repo = MiqAeGit.new(:path => domain_dir, :new => true, :bare => true,
                                :name => name, :email => email)
      end
      git_repo
    end

    def git_user_info(git_repo)
      name = User.current_user ? User.current_user.name : DEFAULT_GIT_USER
      email = User.current_user ? User.current_user.email : nil
      email ||= DEFAULT_GIT_EMAIL
      git_repo.email = email
      git_repo.name  = name
    end

    def domain_dir(domain)
      return nil unless File.exist?(MiqAeDatastore::DATASTORE_DIRECTORY)
      Dir.entries(MiqAeDatastore::DATASTORE_DIRECTORY).detect { |d| d.casecmp(domain) == 0 }
    end

    def load_method_file(filename, location, language, git_repo)
      script_file = method_file_name(filename, location, language)
      return nil unless script_file
      entry = git_repo.find_entry(script_file)
      entry ? git_repo.read_entry(entry) : nil
    end

    def method_file_name(filename, location, language)
      return nil if location.casecmp('builtin') == 0
      return nil if location.casecmp('uri') == 0
      return filename.gsub('.yaml', '.rb') if language.casecmp('ruby') == 0
    end

    def tree_entries(git_repo, parent_dir, yaml_file, filters, overwrite_name = false)
      parent_dir = parent_dir.downcase
      git_repo.nodes(parent_dir).collect do |node|
        next unless node[:type] == :tree
        partial_name = node[:name].split('.')[0] if node[:name].ends_with?(CLASS_DIR_SUFFIX)
        name = partial_name || node[:name]
        next unless item_matches?(name, filters)
        entry = git_repo.find_entry(File.join(parent_dir, node[:name], yaml_file))
        next unless entry
        entry[:name] = name if overwrite_name
        entry
      end.compact
    end

    def item_matches?(item, filters)
      filters.any? { |f| File.fnmatch(f, item, File::FNM_CASEFOLD) }
    end

    def delete_directory(full_name)
      full_name = full_name.downcase
      domain, dir = split_path(full_name)
      git_repo    = git_repository(domain)
      return false unless git_repo
      if dir.empty?
        git_repo.delete_repo
      else
        return false unless git_repo.directory?(dir)
        git_user_info(git_repo)
        git_repo.remove_dir(dir)
        git_repo.save_changes("Removing Directory #{dir}", :local)
      end
    end

    def rename_ae_dir(domain, old_dir, new_dir, entry = nil)
      git_repo = git_repository(domain)
      return false unless git_repo
      return false unless git_repo.directory_exists?(old_dir)
      git_user_info(git_repo)
      git_repo.add(entry) if entry
      git_repo.mv_dir(old_dir, new_dir)
      git_repo.save_changes("Moved directory #{old_dir} to #{new_dir}", :local)
    end

    def delete_file(full_name)
      domain, fname = split_path(full_name.downcase)
      git_repo      = git_repository(domain)
      return false unless git_repo
      return false unless git_repo.file_exists?(fname)
      git_user_info(git_repo)
      git_repo.remove(fname)
      git_repo.save_changes("Removing File #{fname}", :local)
    end

    def file_attributes(fqname)
      fullname = fqname_to_filename(fqname).downcase
      domain, fname = split_path(fullname)
      git_repo      = git_repository(domain)
      return false unless git_repo
      git_repo.file_attributes(fname)
    end

    def add_files_to_repo(domain, entries)
      git_repo = git_repository(domain)
      return false unless git_repo
      git_user_info(git_repo)
      entries.each { |e| git_repo.add(e) }
      git_repo.save_changes("Files Added #{entries.collect { |e| e[:path] }}", :local)
    end

    def remove_files_from_repo(domain, entries)
      git_repo = git_repository(domain)
      return false unless git_repo
      git_user_info(git_repo)
      entries.each { |e| git_repo.remove(e[:path]) }
      git_repo.save_changes("Files Removed #{entries.collect { |e| e[:path] }}", :local)
    end

    def move_files_in_repo(domain, entries)
      git_repo = git_repository(domain)
      return false unless git_repo
      git_user_info(git_repo)
      entries.each do |e|
        e.key?(:data) ?  git_repo.mv_file_with_new_contents(e[:old_path], e) : git_repo.mv_file(e[:old_path], e[:path])
      end
      git_repo.save_changes("Files Moved #{entries.collect { |e| e[:old_path] }.join('\n')}", :local)
    end

    def load_ae_entry(git_repo, entry, klass = nil)
      yaml_hash = YAML.load(git_repo.read_entry(entry))
      fq_name_updated = klass ? klass.filename_to_fqname(entry[:full_name]) : filename_to_fqname(entry[:full_name])
      attrs = object_attributes(fq_name_updated.downcase, yaml_hash)
      obj = klass ? klass.new_with_hash(attrs) : new_with_hash(attrs)
      obj.load_embedded_information(yaml_hash, git_repo) if obj.respond_to?(:load_embedded_information)
      obj
    end

    def object_attributes(fqname, yaml_hash)
      fqname = fqname[1..-1] if fqname[0] == '/'
      attrs = yaml_hash['object']['attributes']
      attrs[:id] = fqname_to_id("/#{fqname}")
      k, v = parent_id(yaml_hash['object_type'], fqname)
      attrs[k] = v ? fqname_to_id(v) : nil
      attrs[:fqname] = "/#{fqname}"
      attrs
    end

    def parent_id(object_type, fqname)
      parts = fqname.split('/')
      parts.pop
      value = "/#{parts.join('/')}"
      key = :parent_id

      case object_type
      when 'domain'
        value = nil
      when 'class'
        key = :namespace_id
      when 'instance', 'method'
        key = :class_id
      end
      return key, value
    end
  end

  # Instance Methods
  def setup_envelope(obj_type)
    {'object_type' => obj_type,
     'version'     => OBJ_YAML_VERSION,
     'object'      => {'attributes' => export_attributes}}
  end

  def uniqueness_of_name
    errors.add(:name, "#{name} already exists as #{fqname}") if self.class.exists?(fqname)
  end

  def write_data(fqpath, hash)
    domain, fname = self.class.split_path(fqpath)
    entry = {:path => File.join(fname, hash['filename'].downcase), :data => hash['data']}
    self.class.add_files_to_repo(domain, entry)
  end

  def load_class_children(klass, sub_dir = nil, filter = '*')
    parent_fq = fqname
    git_repo, parent_dir = self.class.git_repo_fqname(parent_fq)
    parent_dir = "#{parent_dir}#{CLASS_DIR_SUFFIX}"
    child_dir = sub_dir ? File.join(parent_dir, sub_dir) : parent_dir
    return [] unless git_repo

    child_dir = child_dir.downcase
    return [] unless git_repo.file_exists?(child_dir)
    result = []
    git_repo.nodes(child_dir).each do |entry|
      next if entry[:name] == CLASS_YAML_FILE
      next unless File.extname(entry[:name]) == '.yaml'
      basename = File.basename(entry[:name], '.yaml')
      next unless File.fnmatch(filter, basename, File::FNM_CASEFOLD | File::FNM_DOTMATCH)
      result << self.class.load_ae_entry(git_repo, entry, klass)
    end
    result
  end

  def load_class_methods(filter = '*')
    load_class_children(MiqAeMethod, METHODS_DIRECTORY, filter) +
      load_class_children(MiqAeMethod, "#{METHODS_DIRECTORY}/#{CLASS_SCOPE_PREFIX}", filter)
  end

  def load_namespace_children(klass, base_filename, filters)
    git_repo, parent_dir = self.class.git_repo_fqname(fqname)
    return [] unless git_repo
    entries = self.class.tree_entries(git_repo, parent_dir, base_filename, filters, true)
    entries.collect do |entry|
      self.class.load_ae_entry(git_repo, entry, klass)
    end
  end

  def dirname
    @dirname ||= File.dirname(self.class.fs_name(self.class.fqname_to_filename(fqname)))
  end

  def git_filename
    self.class.fqname_to_filename(fqname).split('/')[2..-1].join('/')
  end

  def domain_value
    @domain ||= fqname.split('/')[1]
  end

  def delete_method_file
    method_file = self.class.method_file_name("#{name}.yaml", location, language)
    return unless method_file
    method_file = File.join(dirname, method_file)
    self.class.delete_file(method_file)
  end

  def reload
    git_repo, filename = self.class.git_repo_fqname(self.class.fqname_to_filename(fqname))
    raise "#{fqname} doesn't have a valid git repository" unless git_repo
    raise "#{fqname} doesn't have a valid file" if filename.empty?
    yaml_hash = YAML.load(git_repo.read_file(filename))
    update_attributes(yaml_hash['object']['attributes'])
    refresh_associations(yaml_hash)
    self
  end
end
