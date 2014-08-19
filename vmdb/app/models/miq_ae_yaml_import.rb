class MiqAeYamlImport
  include MiqAeYamlImportExportMixin

  def initialize(domain, options)
    @domain_name = domain
    @options     = options
    @restore     = @options.fetch('restore', false)
  end

  def import
    if @options.key?('import_dir') && !File.directory?(@options['import_dir'])
      raise MiqAeException::DirectoryNotFound, "Directory [#{@options['import_dir']}] not found"
    end
    start_import(@options['preview'], @domain_name)
  end

  def start_import(preview, domain_name)
    if @options['import_as'] && !new_domain_name_valid?
      raise MiqAeException::InvalidDomain, "Error - New domain exists already, #{@options['import_as']}"
    end
    @preview = preview
    $log.info("#{self.class} Import options: <#{@options}> preview: <#{@preview}>")
    $log.info("#{self.class} Importing domain:    <#{domain_name}>")
    reset_stats
    @single_domain = true
    domain_name == ALL_DOMAINS ? import_all_domains : import_domain(domain_folder(domain_name), domain_name)
    log_stats
  end

  def log_stats
    $log.info("#{self.class} Import statistics: <#{@import_stats.inspect}>")
    if @preview
      $log.warn("Your database has NOT been updated. Set PREVIEW=false to apply the above changes.")
    else
      $log.info("Your database has been updated.")
    end
  end

  def reset_stats
    @import_stats = {:domain => Hash.new(0), :namespace => Hash.new(0),
                     :class  => Hash.new(0), :instance => Hash.new(0),
                     :method => Hash.new(0)}
  end

  def import_all_domains
    @single_domain = false
    sorted_domain_files.each do |file|
      directory = File.dirname(file)
      @domain_name = directory.split("/").last
      import_domain(directory, @domain_name)
    end
    MiqAeDatastore.reset_default_namespace if @restore && !@preview
  end

  def sorted_domain_files
    domains = {}
    domain_files(ALL_DOMAINS).sort.each do |file|
      directory = File.dirname(file)
      domain_name = directory.split("/").last
      domain_yaml = read_domain_yaml(directory, domain_name)
      domains[file] = domain_yaml.fetch_path('object', 'attributes', 'priority')
    end
    domains.keys.sort { |a, b| domains[a] <=> domains[b] }
  end

  def import_domain(domain_folder, domain_name)
    domain_yaml = domain_properties(domain_folder, domain_name)
    domain_name = domain_yaml.fetch_path('object', 'attributes', 'name')
    domain_obj = MiqAeDomain.find_by_fqname(domain_name, false)
    track_stats('domain', domain_obj)
    domain_obj ||= add_domain(domain_yaml) unless @preview
    if @options['namespace']
      import_namespace(File.join(domain_folder, @options['namespace']), domain_obj, domain_name)
    else
      import_all_namespaces(domain_folder, domain_obj, domain_name)
    end
    update_attributes(domain_obj) if @single_domain && domain_obj
  end

  def domain_properties(domain_folder, name)
    domain_yaml = read_domain_yaml(domain_folder, name)
    if @options['import_as'] && @single_domain
      name = @options['import_as']
      domain_yaml.store_path('object', 'attributes', 'name', name)
    end
    miq = name.downcase == MiqAeDatastore::MANAGEIQ_DOMAIN.downcase
    miq ? reset_manageiq_attributes(domain_yaml) : reset_domain_attributes(domain_yaml)
    domain_yaml
  end

  def reset_manageiq_attributes(domain_yaml)
    domain_yaml.store_path('object', 'attributes', 'name', MiqAeDatastore::MANAGEIQ_DOMAIN)
    domain_yaml.store_path('object', 'attributes', 'priority', MiqAeDatastore::MANAGEIQ_PRIORITY)
    domain_yaml.store_path('object', 'attributes', 'system', true)
    domain_yaml.store_path('object', 'attributes', 'enabled', true)
  end

  def reset_domain_attributes(domain_yaml)
    domain_yaml.delete_path('object', 'attributes', 'enabled') unless @restore
    domain_yaml.delete_path('object', 'attributes', 'priority')
  end

  def import_all_namespaces(namespace_folder, domain_obj, domain_name)
    namespace_files(namespace_folder).sort.each do |file|
      import_namespace(File.dirname(file), domain_obj, domain_name)
    end
  end

  def import_namespace(namespace_folder, domain_obj, domain_name)
    namespace_file = File.join(namespace_folder, NAMESPACE_YAML_FILENAME)
    process_namespace(domain_obj, namespace_folder, load_file(namespace_file), domain_name)
  end

  def process_namespace(domain_obj, namespace_folder, namespace_yaml, domain_name)
    fqname = "#{domain_name}#{namespace_folder.sub(domain_folder(@domain_name), '')}"
    $log.info("#{self.class} Importing namespace: <#{fqname}>")
    namespace_obj = MiqAeNamespace.find_by_fqname(fqname, false)
    track_stats('namespace', namespace_obj)
    namespace_obj ||= add_namespace(fqname) unless @preview
    if @options['class_name']
      import_class(File.join(namespace_folder, "#{@options['class_name']}#{CLASS_DIR_SUFFIX}"), namespace_obj)
    else
      import_all_classes(namespace_folder, namespace_obj)
      import_all_namespaces(namespace_folder, domain_obj, domain_name)
    end
  end

  def import_all_classes(namespace_folder, namespace_obj)
    class_files(namespace_folder).each do |file|
      import_class(File.dirname(file), namespace_obj)
    end
  end

  def import_class(class_folder, namespace_obj)
    class_obj = existing_class_object(namespace_obj, load_class_schema(class_folder))
    process_class_components(class_folder, namespace_obj) if class_obj.nil?
  end

  def process_class_components(class_folder, namespace_obj)
    class_obj = process_class_schema(namespace_obj, load_class_schema(class_folder))
    add_class_components(class_folder, class_obj)
  end

  def add_class_components(class_folder, class_obj)
    $log.info("#{self.class} Importing class:     <#{class_obj.name}>") unless @preview
    get_instance_files(class_folder).each do |file|
      process_instance(class_obj, load_file(file)) unless File.basename(file) == CLASS_YAML_FILENAME
    end
    get_method_files(class_folder).each do |file|
      process_method(class_obj, file, load_file(file))
    end
  end

  def process_class_schema(namespace_obj, class_yaml)
    class_obj = existing_class_object(namespace_obj, class_yaml)
    class_obj ||= add_class_schema(namespace_obj, class_yaml) unless @preview
    class_obj
  end

  def existing_class_object(ns_obj, class_yaml)
    class_attrs = class_yaml.fetch_path('object', 'attributes')
    class_obj = MiqAeClass.find_by_namespace_id_and_name(ns_obj.id, class_attrs['name']) unless ns_obj.nil?
    track_stats('class', class_obj)
    class_obj
  end

  def process_instance(class_obj, instance_yaml)
    inst_attrs   = instance_yaml.fetch_path('object', 'attributes')
    instance_obj = MiqAeInstance.find_by_class_id_and_name(class_obj.id, inst_attrs['name']) unless class_obj.nil?
    track_stats('instance', instance_obj)
    instance_obj ||= add_instance(class_obj, instance_yaml) unless @preview
    instance_obj
  end

  def process_method(class_obj, ruby_method_file_name, method_yaml)
    method_attributes = method_yaml.fetch_path('object', 'attributes')
    if method_attributes['location'] == 'inline'
      method_yaml.store_path('object', 'attributes', 'data', load_method_ruby(ruby_method_file_name))
    end
    method_obj = MiqAeMethod.find_by_name_and_class_id(method_attributes['name'], class_obj.id) unless class_obj.nil?
    track_stats('method', method_obj)
    method_obj ||= add_method(class_obj, method_yaml) unless @preview
    method_obj
  end

  def track_stats(level, object)
    mode = object.nil? ? 'add' : 'update'
    @import_stats[level.to_sym][mode] += 1
  end

  def new_domain_name_valid?
    return true if @options['overwrite']

    domain_obj = MiqAeDomain.find_by_fqname(@options['import_as'], false)
    if domain_obj
      $log.info("#{self.class} Cannot import - A domain exists with new domain name: #{@options['import_as']}.")
      return false
    end
    true
  end

  def update_attributes(domain_obj)
    return if domain_obj.name.downcase == MiqAeDatastore::MANAGEIQ_DOMAIN.downcase
    attrs = @options.slice('enabled', 'system')
    domain_obj.update_attributes(attrs) unless attrs.empty?
  end
end # class
