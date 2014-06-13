class MiqAeYamlImportFs < MiqAeYamlImport
  def domain_folder(domain_name)
    File.join(@options['import_dir'], domain_name)
  end

  def read_domain_yaml(dom_folder, domain_name)
    domain_yaml_filename = File.join(dom_folder, DOMAIN_YAML_FILENAME)
    unless File.exist?(domain_yaml_filename)
      $log.info("#{self.class} domain: <#{domain_name}> yaml file not found: <#{domain_yaml_filename}>")
      raise MiqAeException::NamespaceNotFound, "domain: #{domain_name} yaml file not found: #{domain_yaml_filename}"
    end
    load_file(domain_yaml_filename)
  end

  def domain_files(domain)
    Dir.glob(File.join(@options['import_dir'], domain, DOMAIN_YAML_FILENAME)).sort
  end

  def namespace_files(parent_folder)
    Dir.glob(File.join(parent_folder, "*", NAMESPACE_YAML_FILENAME)).sort
  end

  def class_files(namespace_folder)
    Dir.glob(File.join(namespace_folder, "*", CLASS_YAML_FILENAME)).sort
  end

  def load_class_schema(class_folder)
    raise MiqAeException::DirectoryNotFound, "Folder [#{class_folder}] not found" \
      unless File.directory?(class_folder)
    load_file(File.join(class_folder, CLASS_YAML_FILENAME))
  end

  def get_instance_files(class_folder)
    Dir.glob(File.join(class_folder, '*.yaml')).sort
  end

  def get_method_files(class_folder)
    Dir.glob(File.join(File.join(class_folder, METHOD_FOLDER_NAME), '*.yaml')).sort
  end

  def load_file(file)
    YAML.load_file(file)
  end

  def load_method_ruby(method_file_name)
    ruby_method_filename = method_file_name.gsub('.yaml', '.rb')
    File.read(ruby_method_filename) if File.exist?(ruby_method_filename)
  end
end
