class MiqAeClass < MiqAeBase
  include MiqAeModelBase
  include MiqAeFsStore

  expose_columns :namespace_id, :namespace
  expose_columns :description, :display_name, :name
  expose_columns :id, :created_on, :created_by_user_id
  expose_columns :updated_on, :updated_by, :updated_by_user_id
  expose_columns :updated_by_user_id
  expose_columns :inherits, :visibility, :type

  validate              :uniqueness_of_name, :on => :create
  validates_presence_of :namespace
  validates_presence_of :namespace_id

  FIELD_HM_RELATIONS    = {:class_name => "MiqAeField", :foreign_key => :class_id,
                           :belongs_to => 'ae_class', :save_parent => true}
  INSTANCE_HM_RELATIONS = {:class_name => "MiqAeInstance", :foreign_key => :class_id, :belongs_to => 'ae_class'}
  METHOD_HM_RELATIONS   = {:class_name => "MiqAeMethod",   :foreign_key => :class_id, :belongs_to => 'ae_class'}

  def self.base_class
    MiqAeClass
  end

  def self.base_model
    MiqAeClass
  end

  def self.count
    MiqAeDomain.fetch_count(MiqAeClass)
  end

  def self.column_names
    %w(namespace_id namespace description display_name name id created_on
       created_by_user_id updated_on updated_by updated_by_user_id
       inherits visibility type)
  end

  def initialize(options = {})
    @attributes = HashWithIndifferentAccess.new(options)
    self.ae_fields    = @attributes.delete(:ae_fields)  if @attributes.key?(:ae_fields)
    self.ae_instances = @attributes.delete(:ae_instances) if @attributes.key?(:ae_instances)
    self.ae_methods   = @attributes.delete(:ae_methods) if @attributes.key?(:ae_methods)
    self.ae_namespace = @attributes.delete(:ae_namespace) if @attributes.key?(:ae_namespace)
  end

  def save
    context = persisted? ? :update : :create
    namespace = @attributes[:namespace] if @attributes.key?(:namespace)
    return false unless namespace_valid?
    self.namespace_id ||= MiqAeNamespace.find_or_create_by_fqname(namespace, false).id
    return false unless valid?(context)
    generate_id   unless id
    return false unless save_relationships
    write(context).tap { |result| changes_applied if result }
  end

  def changed?
    new_record? || fields_changed?
  end

  def namespace_valid?
    if namespace_id.nil? && @attributes[:namespace].blank?
      errors.add(:fields, "Namespace not specified")
      return false
    else
      return true
    end
  end

  def ae_fields
    @fields_proxy ||= MiqAeHasManyProxy.new(self, FIELD_HM_RELATIONS)
  end

  def ae_fields=(*obj)
    @fields_proxy = MiqAeHasManyProxy.new(self, FIELD_HM_RELATIONS)
    @fields_proxy.assign(obj)
  end

  def ae_instances=(*obj)
    @instances_proxy = MiqAeHasManyProxy.new(self, INSTANCE_HM_RELATIONS)
    @instances_proxy.assign(obj)
  end

  def ae_methods=(*obj)
    @methods_proxy = MiqAeHasManyProxy.new(self, METHOD_HM_RELATIONS)
    @methods_proxy.assign(obj)
  end

  def ae_instances
    @instances_proxy ||= MiqAeHasManyProxy.new(self, INSTANCE_HM_RELATIONS, load_class_children(::MiqAeInstance))
  end

  def ae_methods
    @methods_proxy ||= MiqAeHasManyProxy.new(self, METHOD_HM_RELATIONS, load_class_methods)
  end

  def generate_id
    self.id = self.class.fqname_to_id(fqname.downcase)
  end

  def self.find_by_fqname(fq_name, _args = {})
    return nil if fq_name.blank?
    fq_name = fq_name.downcase
    git_repo, path = git_repo_fqname(fq_name)
    return nil unless git_repo
    entry = class_entry(git_repo, path)
    load_ae_entry(git_repo, entry) if entry
  end

  def self.git_entry_exists?(fqname)
    git_repo, path = git_repo_fqname(fqname)
    entry = class_entry(git_repo, path) if git_repo
    entry ? true : false
  end

  def self.class_entry(git_repo, path)
    git_repo.find_entry(File.join("#{path}#{CLASS_DIR_SUFFIX}", CLASS_YAML_FILE))
  end

  def self.find_by_namespace_and_name(ns, name, _args = {})
    return nil if ns.blank? || name.blank?
    find_by_fqname("#{ns}/#{name}")
  end

  def self.find_by_namespace_id_and_name(ns_id, name)
    return nil if ns_id.blank? || name.blank?
    find_by_fqname("#{MiqAeNamespace.id_to_fqname(ns_id)}/#{name}")
  end

  def self.find_by_name_and_namespace_id(name, ns_id)
    find_by_namespace_id_and_name(ns_id, name)
  end

  def self.find_by_name(name)
    MiqAeDomain.fetch_by_name(name, MiqAeClass)
  end

  def self.first
    find_by_name('*')
  end

  def self.find_by_name_old_should_delete(name)
    obj = nil
    MiqAeDomain.all.each do |dom|
      dom.ae_namespaces.each do |ns|
        obj = ns.ae_classes.detect { |klass| klass.name.casecmp(name) == 0 }
        return obj if obj
      end
    end
    nil
  end

  def self.fqname(ns, name)
    "#{ns}/#{name}"
  end

  def self.parse_fqname(fqname)
    parts = fqname.split('/')
    name = parts.pop
    ns = parts.join('/')
    return ns, name
  end

  def ae_namespace
    @ae_namespace ||= ae_ns_obj
  end

  def ae_namespace=(obj)
    @ae_namespace = obj
    @attributes[:namespace_id] = obj.id
    @attributes[:namespace]    = obj.name
  end

  def export_schema
    ae_fields.sort_by(&:priority).collect(&:to_export_yaml)
  end

  def fqname
    @fqname ||= attributes[:fqname]
    @fqname ||= self.class.fqname(namespace, name)
  end

  def fqname_from_objects
    @fqname_slow ||= self.class.fqname(namespace, name)
  end

  def domain
    ae_namespace.domain
  end

  def ae_ns_obj
    if self[:namespace_id].present?
      MiqAeNamespace.find(self[:namespace_id])
    elsif self[:namespace].present?
      MiqAeNamespace.find_by_fqname(self[:namespace])
    end
  end

  def old_namespace
    ns_obj = ae_namespace
    ns_obj.nil? ? nil : ae_namespace.fqname
  end

  def destroy
    self.class.delete_directory(dirname)
    self
  end

  def namespace
    ae_namespace.nil? ? nil : ae_namespace.fqname_from_objects
  end

  def namespace=(ns)
    raise ArgumentError, "ns cannot be blank" if ns.blank?
    self.ae_namespace = MiqAeNamespace.find_or_create_by_fqname(ns)
  end

  def add_relations(yaml_hash)
    @methods_proxy = MiqAeHasManyProxy.new(self, METHOD_HM_RELATIONS, load_class_children(::MiqAeMethod, '__methods__'))
    @instances_proxy = MiqAeHasManyProxy.new(self, INSTANCE_HM_RELATIONS, load_class_children(::MiqAeInstance))
    load_all_fields(yaml_hash, nil)
  end

  def load_all_fields(yaml_hash, _git_repo)
    all_fields = []
    yaml_hash['object']['schema'].each do |f|
      field_id = "#{id}##{f['field']['name'].downcase}"
      hash = {:class_id => id, :id => "#{field_id}"}
      all_fields << ::MiqAeField.new(hash.merge(f['field']))
    end
    self.ae_fields = all_fields
  end

  def self.filename_to_fqname(filename)
    class_dir = File.dirname(filename)
    class_dir.gsub(CLASS_DIR_SUFFIX, "")
  end

  def self.fqname_to_filename(fqname)
    options = {:has_instance_name => false}
    domain, nsd, klass, _ = ::MiqAeEngine::MiqAePath.get_domain_ns_klass_inst(fqname, options)
    return "#{domain}/#{klass}#{CLASS_DIR_SUFFIX}/#{CLASS_YAML_FILE}" if nsd.blank?
    "#{domain}/#{nsd}/#{klass}#{CLASS_DIR_SUFFIX}/#{CLASS_YAML_FILE}"
  end

  def self.find(id)
    return nil if id.blank?
    find_by_fqname(id_to_fqname(id))
  end

  def self.find_by_id(id)
    find(id)
  end

  def instance_methods
    @instance_methods ||= scoped_methods('instance')
  end

  def class_methods
    @class_methods ||= scoped_methods('class')
  end

  def self.find_homonymic_instances_across_domains(fqname)
    return [] if fqname.blank?
    path = MiqAeEngine::MiqAeUri.path(fqname, "miqaedb")
    ns, klass, inst = MiqAeEngine::MiqAePath.split(path)
    return [] if ns.blank? || klass.blank? || inst.blank?
    get_same_instance_from_classes(get_sorted_homonym_class_across_domains(ns, klass), inst)
  end

  def self.find_distinct_instances_across_domains(fqname)
    return [] if fqname.blank?
    ns, klass = fqname.starts_with?('/') ? parse_fqname(fqname[1..-1]) : parse_fqname(fqname)
    return [] if ns.blank? || klass.blank?
    get_unique_instances_from_classes(get_sorted_homonym_class_across_domains(ns, klass))
  end

  def editable?
    ae_namespace.editable?
  end

  def field_names
    ae_fields.collect { |x| x.name.downcase }
  end

  def field_hash(name)
    field = ae_fields.detect { |f| f.name.casecmp(name) == 0 }
    raise "field #{name} not found in class" if field.nil?
    field.attributes
  end

  def self.copy(options)
    if options[:new_name]
      MiqAeClassCopy.new(options[:fqname]).as(options[:new_name],
                                              options[:namespace],
                                              options[:overwrite_location]
      )
    else
      MiqAeClassCopy.copy_multiple(options[:ids],
                                   options[:domain],
                                   options[:namespace],
                                   options[:overwrite_location]
      )
    end
  end

  def load_children
    ae_instances
  end

  alias_method :load_embedded_information, :load_all_fields

  def to_export_xml(options = {})
    require 'builder'
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml_attrs = {:name => name, :namespace => namespace}

    self.class.column_names.each do |cname|
      # Remove any columns that we do not want to export
      next if %w(id created_on updated_on updated_by).include?(cname) || cname.ends_with?("_id")

      # Skip any columns that we process explicitly
      next if %w(name namespace).include?(cname)

      # Process the column
      xml_attrs[cname.to_sym]  = send(cname)   unless send(cname).blank?
    end

    xml.MiqAeClass(xml_attrs) do
      ae_methods.sort { |a, b| a.fqname <=> b.fqname }.each { |m| m.to_export_xml(:builder => xml) }
      xml.MiqAeSchema do
        ae_fields.sort { |a, b| a.priority <=> b.priority }.each { |f| f.to_export_xml(:builder => xml) }
      end unless ae_fields.length == 0
      ae_instances.sort { |a, b| a.fqname <=> b.fqname }.each { |i| i.to_export_xml(:builder => xml) }
    end
  end

  private

  def scoped_methods(s)
    ae_methods.select { |m| m.scope == s }
  end

  def self.get_sorted_homonym_class_across_domains(ns = nil, klass)
    ns_obj = MiqAeNamespace.find_by_fqname(ns) unless ns.nil?
    partial_ns = ns_obj.nil? ? ns : remove_domain_from_fqns(ns)
    domain_list = MiqAeDomain.all_domains.reverse.collect(&:name)
    class_array = domain_list.collect do |domain|
      fq_ns = domain + "/" + partial_ns
      ae_ns = MiqAeNamespace.find_by_fqname(fq_ns)
      next if ae_ns.nil?
      ae_ns.ae_classes.select { |c| File.fnmatch(klass, c.name, File::FNM_CASEFOLD) }
    end.compact.flatten
    if class_array.empty? && ns_obj
      class_array = ns_obj.ae_classes.select { |c| File.fnmatch(klass, c.name, File::FNM_CASEFOLD)   }
    end
    class_array
  end

  def self.remove_domain_from_fqns(fqname)
    parts = fqname.split('/')
    parts.shift
    parts.join('/')
  end

  def self.get_unique_instances_from_classes(klass_array)
    name_set = Set.new
    klass_array.collect do |klass|
      cls = find_by_id(klass.id)
      next if cls.nil?
      cls.ae_instances.sort { |a, b| a.fqname <=> b.fqname }.collect do |inst|
        next if name_set.include?(inst.name)
        name_set << inst.name
        inst
      end.compact.flatten
    end.compact.flatten
  end

  def self.get_same_instance_from_classes(klass_array, instance)
    klass_array.collect do |klass|
      cls = find_by_id(klass.id)
      next if cls.nil?
      cls.ae_instances.select { |a| File.fnmatch(instance, a.name, File::FNM_CASEFOLD) }
    end.compact.flatten
  end

  def self.get_homonymic_across_domains(fqname, enabled = nil)
    MiqAeDatastore.get_homonymic_across_domains(::MiqAeClass, fqname, enabled)
  end

  def refresh_associations(yaml_hash)
    add_relations(yaml_hash)
  end

  def save_relationships
    auto_save_fields && save_children(@instances_proxy) && save_children(@methods_proxy)
  end

  def save_children(objs)
    return true unless objs
    objs.each do |o|
      next unless o.changed?
      o.ae_class = self
      errors.add(:children, o.errors.full_messages.join(' ')) unless o.save
    end
    errors.empty?
  end

  def auto_save_fields
    ae_fields.each do |f|
      f.ae_class = self
      errors.add(:fields, f.errors.full_messages.join(' ')) unless f.auto_save
    end
    errors.empty?
  end

  def fields_changed?
    ae_fields.any?(&:changed)
  end

  def write(context)
    hash = setup_envelope(CLASS_OBJ_TYPE)
    hash['object']['schema'] = export_schema
    sub_dir = "#{fqname}#{CLASS_DIR_SUFFIX}"
    entry = {:path => self.class.relative_filename(sub_dir, CLASS_YAML_FILE),
             :data => hash.to_yaml}
    if context == :update && changes.key?('name')
      mv_class_dir(changes['name'][0], entry)
    else
      self.class.add_files_to_repo(domain_value, [entry])
    end
  end

  def mv_class_dir(old_name, entry)
    @fqname = File.join(ae_namespace.fqname, name).downcase
    generate_id
    old_dir = self.class.relative_filename(ae_namespace.fqname, "#{old_name}#{CLASS_DIR_SUFFIX}")
    new_dir = self.class.relative_filename(ae_namespace.fqname, "#{name}#{CLASS_DIR_SUFFIX}")
    self.class.rename_ae_dir(domain_value, old_dir, new_dir, entry)
  end
end
