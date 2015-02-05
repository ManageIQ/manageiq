class MiqAeYamlImportZipfs < MiqAeYamlImport
  def initialize(domain, options)
    super
    @fn_flags  = File::FNM_CASEFOLD | File::FNM_PATHNAME
    load_zip
  end

  def load_zip
    require 'zip/zipfilesystem'

    raise MiqAeException::FileNotFound, "import file: #{@options['zip_file']} not found" \
      unless File.exist?(@options['zip_file'])
    @zip = Zip::ZipFile.open(@options['zip_file'])
    @sorted_entries = @zip.entries.sort
  end

  def domain_entry(domain_name)
    domain_entries(domain_name).first
  end

  def domain_entries(dom_name)
    entries = domain_files(dom_name)
    if entries.empty?
      $log.info("#{self.class} domain: <#{dom_name}> yaml file not found") if $log
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
    glob_str = File.join(domain, DOMAIN_YAML_FILENAME)
    @sorted_entries.select { |entry| File.fnmatch(glob_str, entry.name, @fn_flags) }.sort.collect(&:name)
  end

  def namespace_files(parent_folder)
    glob_str = File.join(parent_folder, "*", NAMESPACE_YAML_FILENAME)
    @sorted_entries.select { |entry| File.fnmatch(glob_str, entry.name, @fn_flags) }.sort.collect(&:name)
  end

  def all_namespace_files
    @sorted_entries.select { |entry| entry.name.match(NAMESPACE_YAML_FILENAME) }
  end

  def remove_unrelated_entries(domain_name)
    unrelated_entries = @sorted_entries.reject { |entry| entry.name.match(domain_name) }

    unrelated_entries.each do |entry|
      remove_entry(entry)
    end

    update_sorted_entries
  end

  def remove_entry(entry)
    @zip.remove(entry)
  end

  def update_sorted_entries
    @sorted_entries = @zip.entries.sort
  end

  def class_files(namespace_folder)
    glob_str = File.join(namespace_folder, "*", CLASS_YAML_FILENAME)
    @sorted_entries.select { |entry| File.fnmatch(glob_str, entry.name, @fn_flags) }.sort.collect(&:name)
  end

  def load_class_schema(class_folder)
    load_file(File.join(class_folder, CLASS_YAML_FILENAME))
  end

  def get_instance_files(class_folder)
    glob_str = File.join(class_folder, "*.yaml")
    flist = @sorted_entries.select { |entry| File.fnmatch(glob_str, entry.name, @fn_flags) }.sort.collect(&:name)
    method_glob_str = File.join(class_folder, METHOD_FOLDER_NAME, "*.yaml")
    flist.delete_if { |file| File.fnmatch(method_glob_str, file, @fn_flags) }
  end

  def get_method_files(class_folder)
    glob_str = File.join(class_folder, METHOD_FOLDER_NAME, "*.yaml")
    @sorted_entries.select { |entry| File.fnmatch(glob_str, entry.name, @fn_flags) }.sort.collect(&:name)
  end

  def load_file(file)
    YAML.load(@zip.file.read(file))
  end

  def load_method_ruby(method_file_name)
    @zip.file.read(method_file_name.gsub('.yaml', '.rb'))
  end
end
