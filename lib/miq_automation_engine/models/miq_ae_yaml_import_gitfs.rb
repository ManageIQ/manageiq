class MiqAeYamlImportGitfs < MiqAeYamlImport
  def initialize(domain, options)
    super
    @fn_flags = File::FNM_CASEFOLD | File::FNM_PATHNAME
    load_repo
  end

  def load_repo
    unless Dir.exist?(@options['git_dir'])
      raise MiqAeException::DirectoryNotFound, "Git repo dir: #{@options['git_dir']} not found"
    end
    @gwt = GitWorktree.new(:path => @options['git_dir'])
    @gwt.branch = @options['branch'] if @options['branch']
    @gwt.tag = @options['tag'] if @options['tag']
    @files = @gwt.file_list
  end

  def domain_entry(domain_name)
    domain_entries(domain_name).first
  end

  def domain_entries(dom_name)
    entries = domain_files(dom_name)
    if entries.empty?
      _log.info("domain: <#{dom_name}> yaml file not found")
      raise MiqAeException::NamespaceNotFound, "domain: #{dom_name}"
    end
    entries
  end

  def domain_folder(domain_name)
    dom_entry = domain_entry(domain_name)
    File.dirname(dom_entry) unless dom_entry.nil?
  end

  def read_domain_yaml(_domain_folder, domain_name)
    load_file(domain_entry(domain_name))
  end

  def domain_files(domain)
    glob_str = if domain == '*' || domain == '.'
                 File.join('**', DOMAIN_YAML_FILENAME)
               else
                 File.join('**', domain, DOMAIN_YAML_FILENAME)
               end
    @files.select { |entry| File.fnmatch(glob_str, entry, @fn_flags) }
  end

  def namespace_files(parent_folder)
    glob_str = if parent_folder == '.'
                 File.join("*", NAMESPACE_YAML_FILENAME)
               else
                 File.join(parent_folder, "*", NAMESPACE_YAML_FILENAME)
               end

    @files.select { |entry| File.fnmatch(glob_str, entry, @fn_flags) }
  end

  def all_namespace_files
    @files.select { |entry| entry.split('/').last.match(NAMESPACE_YAML_FILENAME) }
  end

  def all_class_files
    @files.select { |entry| entry.split('/').last.match(CLASS_YAML_FILENAME) }
  end

  def class_files(namespace_folder)
    glob_str = File.join(namespace_folder, "*", CLASS_YAML_FILENAME)
    @files.select { |entry| File.fnmatch(glob_str, entry, @fn_flags) }
  end

  def load_class_schema(class_folder)
    load_file(File.join(class_folder, CLASS_YAML_FILENAME))
  end

  def get_instance_files(class_folder)
    glob_str = File.join(class_folder, "*.yaml")
    instance_files = @files.select { |entry| File.fnmatch(glob_str, entry, @fn_flags) }

    class_glob_str = File.join(class_folder, CLASS_YAML_FILENAME)
    instance_files.delete_if { |entry| File.fnmatch(class_glob_str, entry, @fn_flags) }
  end

  def get_method_files(class_folder)
    glob_str = File.join(class_folder, METHOD_FOLDER_NAME, "*.yaml")
    @files.select { |entry| File.fnmatch(glob_str, entry, @fn_flags) }
  end

  def load_file(file)
    YAML.load(@gwt.read_file(file))
  end

  def load_method_ruby(method_file_name)
    @gwt.read_file(method_file_name.gsub('.yaml', '.rb'))
  end
end
