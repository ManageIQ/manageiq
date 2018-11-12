class MiqAeClass < ApplicationRecord
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin

  belongs_to :ae_namespace, :class_name => "MiqAeNamespace", :foreign_key => :namespace_id
  has_many   :ae_fields,    -> { order(:priority) }, :class_name => "MiqAeField",     :foreign_key => :class_id,
                            :dependent => :destroy, :autosave => true
  has_many   :ae_instances, -> { preload(:ae_values) }, :class_name => "MiqAeInstance",  :foreign_key => :class_id,
                            :dependent => :destroy
  has_many   :ae_methods,   :class_name => "MiqAeMethod",    :foreign_key => :class_id,
                            :dependent => :destroy

  validates_presence_of   :name, :namespace_id
  validates_uniqueness_of :name, :case_sensitive => false, :scope => :namespace_id
  validates_format_of     :name, :with    => /\A[\w.-]+\z/i,
                                 :message => N_("may contain only alphanumeric and _ . - characters")

  def self.find_by_fqname(fqname, args = {})
    ns, name = parse_fqname(fqname)
    find_by_namespace_and_name(ns, name, args)
  end

  def self.find_by_namespace_and_name(ns, name, _args = {})
    ns = MiqAeNamespace.find_by_fqname(ns)
    return nil if ns.nil?
    ns.ae_classes.detect { |c| name.casecmp(c.name) == 0 }
  end

  def self.find_by_namespace_id_and_name(ns_id, name)
    where(:namespace_id => ns_id).where(["lower(name) = ?", name.downcase]).first
  end

  def self.find_by_name(name)
    where(["lower(name) = ?", name.downcase]).includes([:ae_methods, :ae_fields]).first
  end

  def self.fqname(ns, name)
    "#{ns}/#{name}"
  end

  def export_schema
    ae_fields.sort_by(&:priority).collect(&:to_export_yaml)
  end

  def self.parse_fqname(fqname)
    parts = fqname.split('/')
    name = parts.pop
    ns = parts.join('/')
    return ns, name
  end

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
      ae_methods.sort_by(&:fqname).each { |m| m.to_export_xml(:builder => xml) }
      xml.MiqAeSchema do
        ae_fields.sort_by(&:priority).each { |f| f.to_export_xml(:builder => xml) }
      end unless ae_fields.empty?
      ae_instances.sort_by(&:fqname).each { |i| i.to_export_xml(:builder => xml) }
    end
  end

  def fqname
    self.class.fqname(namespace, name)
  end

  delegate :domain, :to => :ae_namespace

  def namespace
    return nil if ae_namespace.nil?
    ae_namespace.fqname
  end

  def namespace=(ns)
    raise ArgumentError, "ns cannot be blank" if ns.blank?
    self.ae_namespace = MiqAeNamespace.find_or_create_by_fqname(ns)
  end

  def instance_methods
    @instance_methods ||= scoped_methods("instance")
  end

  def class_methods
    @class_methods ||= scoped_methods("class")
  end

  def state_machine?
    ae_fields.any? { |f| f.aetype == 'state' }
  end

  def self.get_homonymic_across_domains(user, fqname, enabled = nil)
    MiqAeDatastore.get_homonymic_across_domains(user, ::MiqAeClass, fqname, enabled)
  end

  def self.find_homonymic_instances_across_domains(user, fqname)
    return [] if fqname.blank?
    path = MiqAeEngine::MiqAeUri.path(fqname, "miqaedb")
    ns, klass, inst = MiqAeEngine::MiqAePath.split(path)
    return [] if ns.blank? || klass.blank? || inst.blank?
    get_same_instance_from_classes(get_sorted_homonym_class_across_domains(user, ns, klass), inst)
  end

  def self.find_distinct_instances_across_domains(user, fqname)
    return [] if fqname.blank?
    ns, klass = fqname.starts_with?('/') ? parse_fqname(fqname[1..-1]) : parse_fqname(fqname)
    return [] if ns.blank? || klass.blank?
    get_unique_instances_from_classes(get_sorted_homonym_class_across_domains(user, ns, klass))
  end

  delegate :editable?, :to => :ae_namespace

  def field_names
    ae_fields.collect { |x| x.name.downcase }
  end

  def field_hash(name)
    field = ae_fields.detect { |f| f.name.casecmp(name) == 0 }
    raise "field #{name} not found in class #{@name}" if field.nil?
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

  def self.waypoint_ids_for_state_machines
    MiqAeClass.all.select(&:state_machine?).each_with_object([]) do |klass, ids|
      ids << "#{klass.class.name}::#{klass.id}"
      sub_namespaces(klass.ae_namespace, ids)
    end
  end

  def self.display_name(number = 1)
    n_('Automate Class', 'Automate Classes', number)
  end

  private

  def self.sub_namespaces(ns_obj, ids)
    loop do
      break if ns_obj.nil? || ids.include?("#{ns_obj.class.name}::#{ns_obj.id}")
      ids << "#{ns_obj.class.name}::#{ns_obj.id}"
      ns_obj = ns_obj.parent
    end
  end

  private_class_method :sub_namespaces

  def scoped_methods(s)
    ae_methods.select { |m| m.scope == s }
  end

  def self.get_sorted_homonym_class_across_domains(user, ns = nil, klass)
    ns_obj = MiqAeNamespace.find_by_fqname(ns) unless ns.nil?
    partial_ns = ns_obj.nil? ? ns : remove_domain_from_fqns(ns)
    class_array = user.current_tenant.visible_domains.pluck(:name).collect do |domain|
      fq_ns = domain + "/" + partial_ns
      ae_ns = MiqAeNamespace.find_by_fqname(fq_ns)
      next if ae_ns.nil?
      ae_ns.ae_classes.select { |c| File.fnmatch(klass, c.name, File::FNM_CASEFOLD) }
    end.compact.flatten
    if class_array.empty? && ns_obj
      class_array = ns_obj.ae_classes.select { |c| File.fnmatch(klass, c.name, File::FNM_CASEFOLD) }
    end
    class_array
  end

  private_class_method :get_sorted_homonym_class_across_domains

  def self.remove_domain_from_fqns(fqname)
    parts = fqname.split('/')
    parts.shift
    parts.join('/')
  end

  private_class_method :remove_domain_from_fqns

  def self.get_unique_instances_from_classes(klass_array)
    name_set = Set.new
    klass_array.collect do |klass|
      cls = find_by(:id => klass.id)
      next if cls.nil?
      cls.ae_instances.sort_by(&:fqname).collect do |inst|
        next if name_set.include?(inst.name)
        name_set << inst.name
        inst
      end.compact.flatten
    end.compact.flatten
  end

  private_class_method :get_unique_instances_from_classes

  def self.get_same_instance_from_classes(klass_array, instance)
    klass_array.collect do |klass|
      cls = find_by(:id => klass.id)
      next if cls.nil?
      cls.ae_instances.select { |a| File.fnmatch(instance, a.name, File::FNM_CASEFOLD) }
    end.compact.flatten
  end

  private_class_method :get_same_instance_from_classes
end
