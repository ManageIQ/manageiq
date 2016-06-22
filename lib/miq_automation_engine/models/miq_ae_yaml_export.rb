class MiqAeYamlExport
  include Vmdb::Logging
  include MiqAeYamlImportExportMixin
  attr_accessor :namespace, :klass, :instance, :method, :zip
  NEW_LINE = "\n"
  MANIFEST_FILE_NAME = '.manifest.yaml'
  FILE_EXTENSIONS = {'ruby' => '.rb', 'perl' => '.pl'}

  def initialize(domain, options)
    @domain        = domain
    @klass         = options['class']
    @namespace     = options['namespace']
    @options       = options
    @tenant        = @options['tenant']
    reset_manifest
  end

  private

  def write_model
    case export_level
    when "class"     then write_class(domain_object, @namespace, @klass.downcase)
    when "namespace" then write_namespace(domain_object, @namespace)
    else
      @domain == ALL_DOMAINS ? write_all_domains : write_domain(domain_object)
    end
    write_manifest(@options['export_as'].presence || @domain)
  end

  def export_level
    if @namespace.present? && @klass.present?
      "class"
    elsif @namespace.present?
      "namespace"
    else
      "domain"
    end
  end

  def write_domain(dom_obj)
    _log.info("Exporting domain:    <#{@domain}>")
    write_domain_file(dom_obj)
    write_all_namespaces(dom_obj)
  end

  def write_namespace(dom_obj, namespace)
    write_multipart_namespace_files(namespace) if namespace.split('/').count > 0
    ns_obj = get_namespace_object(namespace)
    _log.info("Exporting domain:    <#{@domain}> namespace: <#{namespace}>")
    write_domain_file(dom_obj)
    write_namespace_file(ns_obj)
    write_all_classes(ns_obj)
    write_all_namespaces(ns_obj)
  end

  def write_multipart_namespace_files(namespace)
    parts = namespace.split("/").delete_if(&:blank?)
    parts.pop
    parts.each_with_object([]) do |ns, new_ns|
      new_ns << ns
      write_namespace_file(get_namespace_object(new_ns.join('/')))
    end
  end

  def write_class(dom_obj, namespace, class_name)
    ns_obj = get_namespace_object(namespace)
    class_obj = get_class_object(ns_obj, class_name)
    _log.info("Exporting domain:    <#{@domain}> ns: <#{namespace}> class: <#{class_name}>")
    write_domain_file(dom_obj)
    write_namespace_file(ns_obj)
    write_class_components(ns_obj.fqname, class_obj)
  end

  def setup_envelope(obj, obj_type)
    {'object_type' => obj_type,
     'version'     => VERSION,
     'object'      => {'attributes' => obj.export_attributes}}
  end

  def write_domain_file(domain_obj)
    if @options['export_as'].present?
      saved_domain    = domain_obj.name
      domain_obj.name = @options['export_as']
    end
    envelope_hash = setup_envelope(domain_obj, DOMAIN_OBJ_TYPE).to_yaml
    write_export_file('fqname'          => domain_obj.name,
                      'output_filename' => DOMAIN_YAML_FILENAME,
                      'export_data'     => envelope_hash,
                      'created_on'      => domain_obj.created_on,
                      'updated_on'      => domain_obj.updated_on)
    domain_obj.name = saved_domain if saved_domain
  end

  def write_namespace_file(ns_obj)
    _log.info("Exporting namespace: <#{ns_obj.fqname}>")
    envelope_hash = setup_envelope(ns_obj, NAMESPACE_OBJ_TYPE).to_yaml
    write_export_file('fqname'          => swap_domain_path(ns_obj.fqname),
                      'output_filename' => NAMESPACE_YAML_FILENAME,
                      'export_data'     => envelope_hash,
                      'created_on'      => ns_obj.created_on,
                      'updated_on'      => ns_obj.updated_on)
  end

  def domains
    @tenant ? @tenant.ae_domains : MiqAeDomain.all
  end

  def write_all_domains
    domains.each do |dom_obj|
      @domain = dom_obj.name
      write_domain(domain_object)
    end
  end

  def write_all_namespaces(parent_obj)
    parent_obj.ae_namespaces.each do |ns_obj|
      write_namespace_file(ns_obj)
      write_all_classes(ns_obj)
      write_all_namespaces(ns_obj)
    end
  end

  def write_all_classes(ns_obj)
    ns_obj.ae_classes.sort_by(&:name).each do |cls|
      write_class_components(ns_obj.fqname, cls)
    end
  end

  def write_class_components(ns_fqname, class_obj)
    _log.info("Exporting class:     <#{ns_fqname}/#{class_obj.name}>")
    write_class_schema(ns_fqname, class_obj)
    write_all_instances(ns_fqname, class_obj)
    write_all_methods(ns_fqname, class_obj)
  end

  def write_class_schema(ns_fqname, class_obj)
    envelope_hash = setup_envelope(class_obj, CLASS_OBJ_TYPE)
    envelope_hash['object']['schema'] = class_obj.export_schema
    write_export_file('fqname'          => swap_domain_path(ns_fqname),
                      'class_name'      => "#{class_obj.name}#{CLASS_DIR_SUFFIX}",
                      'output_filename' => CLASS_YAML_FILENAME,
                      'export_data'     => envelope_hash.to_yaml,
                      'created_on'      => class_obj.created_on,
                      'updated_on'      => class_obj.updated_on)
    @counts['classes'] += 1
  end

  def write_all_instances(ns_fqname, class_obj)
    export_file_hash = {'fqname'     => swap_domain_path(ns_fqname),
                        'class_name' => "#{class_obj.name}#{CLASS_DIR_SUFFIX}"}
    class_obj.ae_instances.sort_by(&:fqname).each do |inst|
      file_name = inst.name.dup
      file_name[0] = '_' if file_name[0] == '.'
      envelope_hash = setup_envelope(inst, INSTANCE_OBJ_TYPE)
      envelope_hash['object']['fields'] = inst.export_ae_fields
      export_file_hash['output_filename'] = "#{file_name}.yaml"
      export_file_hash['export_data'] = envelope_hash.to_yaml
      export_file_hash['created_on'] = inst.created_on
      export_file_hash['updated_on'] = inst.updated_on
      @counts['instances'] += 1
      write_export_file(export_file_hash)
    end
  end

  def write_all_methods(ns_fqname, class_obj)
    export_file_hash = {'fqname' => swap_domain_path(ns_fqname)}
    export_file_hash['class_name'] = "#{class_obj.name}#{CLASS_DIR_SUFFIX}/#{METHOD_FOLDER_NAME}"
    class_obj.ae_methods.sort_by(&:fqname).each do |meth_obj|
      export_file_hash['created_on'] = meth_obj.created_on
      export_file_hash['updated_on'] = meth_obj.updated_on
      write_method_file(meth_obj, export_file_hash) unless meth_obj.location == 'builtin'
      write_method_attributes(meth_obj, export_file_hash)
    end
  end

  def write_method_attributes(method_obj, export_file_hash)
    envelope_hash = setup_envelope(method_obj, METHOD_OBJ_TYPE)
    envelope_hash['object']['inputs'] = method_obj.method_inputs
    envelope_hash['object']['attributes'].delete('data')
    export_file_hash['output_filename'] = "#{method_obj.name}.yaml"
    export_file_hash['export_data']     = envelope_hash.to_yaml
    @counts['method_instances'] += 1
    write_export_file(export_file_hash)
  end

  def write_method_file(method_obj, export_file_hash)
    @counts['method_files'] += 1
    export_file_hash['output_filename'] = get_method_filename(method_obj)
    if method_obj.data
      method_obj.data += NEW_LINE unless method_obj.data.end_with?(NEW_LINE)
    end
    export_file_hash['export_data'] = method_obj.data || ""
    write_export_file(export_file_hash)
  end

  def get_method_filename(method_obj)
    if method_obj['location'] == 'inline'
      "#{method_obj.name}#{FILE_EXTENSIONS[method_obj.language]}"
    elsif method_obj['location'] == 'uri'
      "#{method_obj.name}.uri"
    end
  end

  def write_export_file(export_hash)
    base_path = export_hash['fqname']
    base_path = File.join(base_path, export_hash['class_name']) unless export_hash['class_name'].nil?
    write_data(base_path, export_hash)
    add_to_manifest(base_path, export_hash)
  end

  def add_to_manifest(base_path, export_hash)
    parts = base_path.split('/')
    parts.shift
    fname = parts.empty? ? export_hash['output_filename'] : File.join(parts.join('/'), export_hash['output_filename'])
    @manifest[fname] = {'created_on' => export_hash['created_on'],
                        'updated_on' => export_hash['updated_on'],
                        'size'       => export_hash['export_data'].length,
                        'sha1'       => Digest::SHA1.base64digest(export_hash['export_data'])}
  end

  def write_manifest(domain_name)
    update_counts
    export_hash = {'output_filename' => MANIFEST_FILE_NAME, 'export_data' => @manifest.to_yaml}
    write_data(domain_name, export_hash)
    reset_manifest
  end

  def update_counts
    @manifest[DOMAIN_YAML_FILENAME] = @counts.merge(@manifest[DOMAIN_YAML_FILENAME])
  end

  def reset_manifest
    @manifest = {DOMAIN_YAML_FILENAME => {}}
    @counts   = Hash.new { |h, k| h[k] = 0 }
  end

  def domain_object
    raise MiqAeException::DomainNotAccessible, "Domain [#{@domain}] not accessible" unless domain_accessible?
    MiqAeDomain.find_by_fqname(@domain).tap do |dom|
      if dom.nil?
        _log.error("Domain: <#{@domain}> not found.")
        raise MiqAeException::DomainNotFound, "Domain [#{@domain}] not found in MiqAeDatastore"
      end
      raise MiqAeException::InvalidDomain, "Domain [#{@domain}] is not a valid domain" unless dom.domain?
    end
  end

  def get_namespace_object(namespace)
    fqname = File.join(@domain, namespace)
    MiqAeNamespace.find_by_fqname(fqname) || begin
      _log.error("Namespace: <#{fqname}> not found.")
      raise MiqAeException::NamespaceNotFound, "Namespace: [#{fqname}] not found in MiqAeDatastore"
    end
  end

  def get_class_object(ns_obj, klass)
    ns_obj.ae_classes.detect { |cls| cls.name.downcase == klass } || begin
      _log.error("Class: <#{klass}> not found in <#{ns_obj.fqname}>.")
      raise MiqAeException::ClassNotFound, "Class: [#{klass}] not found in [#{ns_obj.fqname}]"
    end
  end

  def swap_domain_path(fqname)
    return fqname if @options['export_as'].blank?
    fqname.gsub(/^\/#{@domain}/, @options['export_as'])
  end

  def domain_accessible?
    return true unless @tenant
    @tenant.ae_domains.any? { |dom| dom.name.casecmp(@domain) == 0 }
  end
end
