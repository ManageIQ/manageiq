class MiqAeInstance < ApplicationRecord
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin
  include RelativePathMixin

  belongs_to :domain, :class_name => "MiqAeDomain", :inverse_of => false
  belongs_to :ae_class,  -> { includes(:ae_fields) }, :class_name => "MiqAeClass", :foreign_key => :class_id
  has_many   :ae_values, -> { includes(:ae_field) }, :class_name => "MiqAeValue", :foreign_key => :instance_id,
                         :dependent => :destroy, :autosave => true

  before_validation :set_relative_path
  validates         :domain_id, :class_id, :presence => true
  validates         :name, :presence                => true,
                           :uniqueness_when_changed => {:case_sensitive => false,
                                                        :scope          => :class_id},
                           :format                  => {:with    => /\A[\w.-]+\z/i,
                                                        :message => N_("may contain only alphanumeric and _ . - characters")}

  def self.lookup_by_name(name)
    find_by(:lower_name => name.downcase)
  end

  singleton_class.send(:alias_method, :find_by_name, :lookup_by_name)
  Vmdb::Deprecation.deprecate_methods(singleton_class, :find_by_name => :lookup_by_name)

  def get_field_attribute(field, validate, attribute)
    if validate
      field, fname = validate_field(field)
      raise MiqAeException::FieldNotFound, "Field [#{fname}] not found in MiqAeDatastore" if field.nil?
    end

    val = ae_values.detect { |v| v.field_id == field.id }
    val.try(attribute)
  end

  def set_field_attribute(field, value, attribute)
    field, fname = validate_field(field)
    raise MiqAeException::FieldNotFound, "Field [#{fname}] not found in MiqAeDatastore" if field.nil?

    val   = ae_values.detect { |v| v.field_id == field.id }
    val ||= ae_values.build(:field_id => field.id)
    val.send("#{attribute}=", value)
    val.save!
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

  # my instance's fqname is /domain/namespace1/namespace2/class/instance
  def namespace
    fqname.split("/")[0..-3].join("/")
  end

  def export_ae_fields
    ae_values_sorted.collect(&:to_export_yaml).compact
  end

  # TODO: Limit search to within the context of a class id?
  def self.search(str)
    str[-1, 1] = "%" if str[-1, 1] == "*"

    query = where(arel_table[:relative_path].lower.matches(str.downcase, nil, true)) # This uses 'like'.

    domain_id = query.joins(:domain).order("miq_ae_namespaces.priority DESC").limit(1).pluck(:domain_id)
    query.where(:domain_id => domain_id)
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
      ae_values_sorted.each { |v| v.to_export_xml(:builder => xml) }
    end
  end

  def ae_values_sorted
    ae_class.ae_fields.sort_by(&:priority).collect do |field|
      ae_values.detect { |value| value.field_id == field.id }
    end.compact
  end

  delegate :editable?, :to => :ae_class

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

  def self.display_name(number = 1)
    n_('Automate Instance', 'Automate Instances', number)
  end

  def self.find_best_match_by(user, relative_path)
    domain_ids = user.current_tenant.enabled_domains
    joins(:domain).where(:miq_ae_namespaces => {:id => domain_ids})
                  .order("miq_ae_namespaces.priority DESC")
                  .find_by(arel_table[:relative_path].lower.matches(relative_path.downcase, nil, true))
  end

  def self.get_homonymic_across_domains(user, fqname, enabled = nil, prefix: true)
    return get_homonymic_across_domains_noprefix(user, fqname, enabled) unless prefix

    MiqAeDatastore.get_homonymic_across_domains(user, ::MiqAeInstance, fqname, enabled)
  end

  private_class_method def self.get_homonymic_across_domains_noprefix(user, path, enabled = nil)
    return [] if path.blank?

    ns, klass, instance, _ = MiqAeEngine::MiqAePath.split(path)
    MiqAeDatastore.get_sorted_matching_objects(user, ::MiqAeInstance, ns, klass, instance, enabled)
  end

  private

  def set_relative_path
    self.domain_id ||= ae_class&.domain_id
    self.relative_path = "#{ae_class.relative_path}/#{name}" if (name_changed? || relative_path_changed?) && ae_class
  end

  def validate_field(field)
    if field.kind_of?(MiqAeField)
      fname = field.name
      field = nil unless ae_class.ae_fields.include?(field)
    else
      fname = field
      field = ae_class.ae_fields.detect { |f| fname.casecmp(f.name) == 0 }
    end
    return field, fname
  end
end
