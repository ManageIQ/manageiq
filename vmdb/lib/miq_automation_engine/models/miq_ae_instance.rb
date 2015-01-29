class MiqAeInstance < MiqAeBase
  include MiqAeModelBase
  include MiqAeFsStore
  expose_columns :class_id, :inherits
  expose_columns :description, :display_name, :name
  expose_columns :id, :created_on, :created_by_user_id
  expose_columns :updated_on, :updated_by, :updated_by_user_id

  validate :uniqueness_of_name, :on => :create
  validates_presence_of :class_id

  VALUE_HM_RELATIONS  = {:class_name => 'MiqAeValue', :foreign_key => :instance_id,
                         :belongs_to => 'ae_instance', :save_parent => true}

  def self.column_names
    %w(class_id inherits description display_name name
       id created_on created_by_user_id updated_on
       updated_by updated_by_user_id)
  end

  def initialize(options = {})
    @attributes = HashWithIndifferentAccess.new(options)
    self.ae_class  = @attributes.delete(:ae_class)  if @attributes.key?(:ae_class)
    self.ae_values = @attributes.delete(:ae_values) if @attributes.key?(:ae_values)
  end

  def self.base_class
    MiqAeInstance
  end

  def self.base_model
    MiqAeInstance
  end

  def self.count
    MiqAeDomain.fetch_count(MiqAeInstance)
  end

  def ae_class
    @ae_class ||= class_id ? MiqAeClass.find(class_id) : nil
  end

  def ae_class=(obj)
    @ae_class = obj
    @attributes[:class_id]  = obj.id
  end

  def ae_values
    @values_proxy ||= MiqAeHasManyProxy.new(self, VALUE_HM_RELATIONS)
  end

  def refresh_associations(_yaml_hash = {})
    @ae_class = MiqAeClass.find(class_id)
  end

  def ae_values=(*obj)
    @values_proxy ||= MiqAeHasManyProxy.new(self, VALUE_HM_RELATIONS)
    @values_proxy.assign(obj)
  end

  def generate_id
    self.id = self.class.fqname_to_id(fqname.downcase)
    self.class_id ||= self.class.fqname_to_id(ae_class.fqname.downcase)
  end

  def changed?
    new_record? || values_changed? || changes.keys.present?
  end

  def save
    return true unless changed?
    context = persisted? ? :update : :create
    return false unless valid?(context)
    generate_id   unless id
    auto_save_values if @values_proxy
    write(context).tap { |result| changes_applied if result }
  end

  def write(context)
    hash = setup_envelope(INSTANCE_OBJ_TYPE)
    hash['object']['fields'] = export_ae_fields
    sub_dir = "#{ae_class.fqname}#{CLASS_DIR_SUFFIX}"
    entry = {:path => self.class.relative_filename(sub_dir, "#{name}.yaml"),
             :data => hash.to_yaml}
    if context == :update && changes.key?('name')
      mv_instance_file(entry, changes['name'][0], sub_dir)
    else
      self.class.add_files_to_repo(domain_value, [entry])
    end
  end

  def mv_instance_file(entry, old_name, sub_dir)
    @fqname = File.join(ae_class.fqname, name).downcase
    generate_id
    entry[:old_path] = self.class.relative_filename(sub_dir, "#{old_name}.yaml")
    self.class.move_files_in_repo(domain_value, [entry])
  end

  def auto_save_values
    @values_proxy.each do |v|
      v.ae_instance = self
      v.auto_save
    end
  end

  def destroy
    filename = self.class.fs_name(self.class.fqname_to_filename(fqname))
    self.class.delete_file(filename)
  end

  def values_changed?
    return true unless @values_proxy
    @values_proxy.any? { |v| v.new_record? || v.changed? }
  end

  def self.find_by_fqname(fqname)
    return nil if fqname.blank?
    fqname = fqname.downcase
    git_repo, path = git_repo_fqname(fqname)
    entry = instance_entry(git_repo, path) if git_repo
    load_ae_entry(git_repo, entry) if entry
  end

  def self.git_entry_exists?(fqname)
    git_repo, path = git_repo_fqname(fqname)
    entry = instance_entry(git_repo, path) if git_repo
    entry ? true : false
  end

  def self.instance_entry(git_repo, path)
    parts = path.split('/')
    instance = parts.pop
    git_repo.find_entry("#{parts.join('/')}#{CLASS_DIR_SUFFIX}/#{instance}.yaml")
  end

  def self.fqname_to_filename(fqname)
    domain, nsd, klass, inst = ::MiqAeEngine::MiqAePath.get_domain_ns_klass_inst(fqname)
    return "#{domain}/#{klass}#{CLASS_DIR_SUFFIX}/#{inst}.yaml" if nsd.blank?
    "#{domain}/#{nsd}/#{klass}#{CLASS_DIR_SUFFIX}/#{inst}.yaml"
  end

  def self.find_all_by_class_id(class_id)
    cls = MiqAeClass.find(class_id)
    cls ? cls.ae_instances : []
  end

  def self.filename_to_fqname(filename)
    inst = File.basename(filename, '.yaml')
    class_dir = File.dirname(filename)
    class_dir = class_dir.gsub(CLASS_DIR_SUFFIX, "")
    "#{class_dir}/#{inst}"
  end

  def self.find_by_id(id)
    find(id)
  end

  def self.find(id)
    return nil if id.blank?
    find_by_fqname(id_to_fqname(id))
  end

  def self.find_by_name(name)
    MiqAeDomain.fetch_by_name(name, MiqAeInstance)
  end

  def self.first
    find_by_name('*')
  end

  def self.find_by_name_and_class_id(name, class_id)
    fq_name = "#{MiqAeClass.id_to_fqname(class_id)}/#{name}"
    find_by_fqname(fq_name)
  end

  def self.find_by_class_id_and_name(class_id, name)
    find_by_name_and_class_id(name, class_id)
  end

  def load_all_values(yaml_hash, _git_repo)
    all_values = []
    yaml_hash['object']['fields'].each do |v|
      field_name = v.keys[0]
      value_hash = v[field_name]
      value_hash[:id] = "#{id}##{field_name.downcase}"
      value_hash[:field_id] = "#{class_id}##{field_name.downcase}"
      value_hash[:instance_id] = id
      all_values << MiqAeValue.new(value_hash)
    end
    self.ae_values = all_values
  end

  alias_method :load_embedded_information, :load_all_values

  def get_field_attribute(field, validate, attribute)
    if validate
      field, fname = validate_field(field)
      raise MiqAeException::FieldNotFound, "Field [#{fname}] not found in MiqAeDatastore" if field.nil?
    end

    val = ae_values.detect { |v| v.field_id.casecmp(field.id) == 0 }
    val.respond_to?(attribute) ? val.send(attribute) : nil
  end

  def set_field_attribute(field, value, attribute)
    field, fname = validate_field(field)
    raise MiqAeException::FieldNotFound, "Field [#{fname}] not found in MiqAeDatastore" if field.nil?

    val   = ae_values.detect { |v| v.field_id.casecmp(field.id) == 0 }
    val ||= build_value(:field_id => field.id, :instance_id => id, :name => field.name)
    val.send("#{attribute}=", value)
    save
  end

  def build_value(options)
    obj = MiqAeValue.new(options)
    ae_values << obj
    obj
  end

  def get_field_collect(field, validate = true)
    get_field_attribute(field, validate, :collect)
  end

  def set_field_collect(field, value)
    set_field_attribute(field, value, :collect)
  end

  def get_field_value(field, validate = true)
    get_field_attribute(field, validate, :value)
  end

  def set_field_value(field, value)
    set_field_attribute(field, value, :value)
  end

  def field_attributes
    result = {}
    ae_class.ae_fields.each do |f|
      result[f.name] = get_field_value(f, false)
    end
    result
  end

  def fqname
    @fqname ||= attributes[:fqname]
    @fqname ||= "#{ae_class.fqname}/#{name}"
  end

  def fqname_from_objects
    @fqname_slow ||= "#{ae_class.fqname_from_objects}/#{name}"
  end

  def domain
    ae_class.domain
  end

  def export_ae_fields
    ae_values_sorted.collect(&:to_export_yaml).compact
  end

  def self.search(str)
    str[-1, 1] = "%" if str[-1, 1] == "*"
    ae_class.ae_instances.select { |f| f.name =~ str }.collect(&:name)
  end

  def to_export_xml(options = {})
    require 'builder'
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml_attrs = {:name => name}

    self.class.column_names.each do |cname|
      # Remove any columns that we do not want to export
      next if %w(id created_on updated_on updated_by).include?(cname) || cname.ends_with?("_id")

      # Skip any columns that we process explicitly
      next if %w(name).include?(cname)

      # Process the column
      xml_attrs[cname.to_sym]  = send(cname)   unless send(cname).blank?
    end

    xml.MiqAeInstance(xml_attrs) do
      ae_values.each { |v| v.to_export_xml(:builder => xml) }
    end
  end

  def ae_values_sorted
    ae_class.ae_fields.sort_by(&:priority).collect do |field|
      ae_values.select { |value| value.field_id == field.id }.first
    end.compact
  end

  def editable?
    ae_class.ae_namespace.editable?
  end

  def field_names
    fields = ae_values.collect(&:field_id)
    ae_class.ae_fields.select { |x| fields.include?(x.id) }.collect { |f| f.name.downcase }
  end

  def field_value_hash(name)
    field = ae_class.ae_fields.detect { |f| f.name.casecmp(name) == 0 }
    raise "Field #{name} not found in class #{ae_class.fqname}" if field.nil?
    value = ae_values.detect { |v| v.field_id == field.id }
    raise "Field #{name} not found in instance #{self.name} in class #{ae_class.fqname}" if value.nil?
    value.attributes
  end

  def self.get_homonymic_across_domains(fqname, enabled = nil)
    MiqAeDatastore.get_homonymic_across_domains(::MiqAeInstance, fqname, enabled)
  end

  def self.copy(options)
    if options[:new_name]
      MiqAeInstanceCopy.new(options[:fqname]).as(options[:new_name],
                                                 options[:namespace],
                                                 options[:overwrite_location]
      )
    else
      MiqAeInstanceCopy.copy_multiple(options[:ids],
                                      options[:domain],
                                      options[:namespace],
                                      options[:overwrite_location]
      )
    end
  end

  def load_children
    ae_values
  end

  private

  def validate_field(field)
    if field.kind_of?(MiqAeField)
      fname = field.name
      field = nil unless ae_class.ae_fields.any? { |f| field.id == f.id }
    else
      fname = field
      field = ae_class.ae_fields.detect { |f| fname.casecmp(f.name) == 0 }
    end
    return field, fname
  end
end
