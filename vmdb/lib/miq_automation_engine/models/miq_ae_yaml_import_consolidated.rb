class MiqAeYamlImportConsolidated < MiqAeYamlImport
  include MiqAeYamlImportExportMixin
  def initialize(domain, options)
    super
    @fn_flags  = File::FNM_CASEFOLD | File::FNM_PATHNAME
    load_yaml
  end

  def load_yaml
    unless File.exist?(@options['yaml_file'])
      raise MiqAeException::FileNotFound, "import file: #{@options['yaml_file']} not found"
    end
    @yaml_model = YAML.load_file(@options['yaml_file'])
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
    entries = domain_files(domain_name)
    entries.empty? ? domain_name : File.dirname(entries.first)
  end

  def read_domain_yaml(_domainfolder, domain_name)
    load_file(domain_entry(domain_name))
  end

  def domain_files(domain)
    keys = @yaml_model.keys
    return [] if keys.empty?
    keys.select! do |key|
      File.fnmatch(domain, key, @fn_flags) && @yaml_model.has_key_path?(*[key, DOMAIN_YAML_FILENAME])
    end
    keys.collect { |key| "#{key}/#{DOMAIN_YAML_FILENAME}" }
  end

  def namespace_files(parent_path)
    get_filenames(parent_path, NAMESPACE_YAML_FILENAME)
  end

  def class_files(parent_path)
    get_filenames(parent_path, CLASS_YAML_FILENAME)
  end

  def get_method_files(parent_path)
    get_filenames_with_proc("#{parent_path}/#{METHOD_FOLDER_NAME}") do |item|
      item.ends_with?('.yaml')
    end
  end

  def get_instance_files(parent_path)
    get_filenames_with_proc(parent_path) do |item|
      item != CLASS_YAML_FILENAME && item != METHOD_FOLDER_NAME
    end
  end

  def load_file(file)
    @yaml_model.fetch_path(*file.split('/'))
  end

  def load_method_ruby(method_file_name)
    load_file(method_file_name.gsub('.yaml', '.rb'))
  end

  def load_class_schema(class_folder)
    class_file = "#{class_folder}/#{CLASS_YAML_FILENAME}"
    @yaml_model.fetch_path(*class_file.split('/'))
  end

  private

  def get_filenames(parent_path, file_name)
    paths = get_filenames_with_proc(parent_path) do |key, hash|
      hash.has_key_path?(*[key, file_name])
    end
    paths.collect { |path| "#{path}/#{file_name}" }
  end

  def get_filenames_with_proc(parent_path)
    path_list = parent_path.split('/')
    return [] unless @yaml_model.has_key_path?(*path_list)

    hash = @yaml_model.fetch_path(*path_list)
    selected_keys = hash.keys.select do |key|
      yield(key, hash)
    end
    selected_keys.sort.collect { |key| "#{parent_path}/#{key}" }
  end
end
