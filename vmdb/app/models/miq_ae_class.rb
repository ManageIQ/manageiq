class MiqAeClass < ActiveRecord::Base
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin

  belongs_to :ae_namespace, :class_name => "MiqAeNamespace", :foreign_key => :namespace_id
  has_many   :ae_fields,    :class_name => "MiqAeField",     :foreign_key => :class_id, :dependent => :destroy, :order => :priority
  has_many   :ae_instances, :class_name => "MiqAeInstance",  :foreign_key => :class_id, :dependent => :destroy, :include => :ae_values
  has_many   :ae_methods,   :class_name => "MiqAeMethod",    :foreign_key => :class_id, :dependent => :destroy

  validates_presence_of   :name, :namespace_id
  validates_uniqueness_of :name, :case_sensitive => false, :scope => :namespace_id
  validates_format_of     :name, :with => /\A[A-Za-z0-9_.-]+\z/i

  include ReportableMixin

  def self.find_by_fqname(fqname, args = {})
    ns, name = self.parse_fqname(fqname)
    self.find_by_namespace_and_name(ns, name, args)
  end

  def self.find_by_namespace_and_name(ns, name, args = {})
    ns = MiqAeNamespace.find_by_fqname(ns)
    return nil if ns.nil?
    ns.ae_classes.detect { |c| name.casecmp(c.name) == 0 }
  end

  def self.find_by_namespace_id_and_name(ns_id, name)
    self.find(:first, :conditions => ["namespace_id = ? AND lower(name) = ?", ns_id, name.downcase] )
  end

  def self.find_by_name(name)
    self.find(:first, :conditions => ["lower(name) = ?", name.downcase], :include => [:ae_methods, :ae_fields] )
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
    xml_attrs = { :name => self.name, :namespace => self.namespace }

    self.class.column_names.each { |cname|
      # Remove any columns that we do not want to export
      next if %w(id created_on updated_on updated_by).include?(cname) || cname.ends_with?("_id")

      # Skip any columns that we process explicitly
      next if %w(name namespace).include?(cname)

      # Process the column
      xml_attrs[cname.to_sym]  = self.send(cname)   unless self.send(cname).blank?
    }

    xml.MiqAeClass(xml_attrs) {
      self.ae_methods.sort{|a,b| a.fqname <=> b.fqname}.each   { |m| m.to_export_xml(:builder => xml) }
      xml.MiqAeSchema {
        self.ae_fields.sort{|a,b| a.priority <=> b.priority}.each  { |f| f.to_export_xml(:builder => xml) }
      } unless self.ae_fields.length == 0
      self.ae_instances.sort{|a,b| a.fqname <=> b.fqname}.each { |i| i.to_export_xml(:builder => xml) }
    }
  end

  def fqname
    return self.class.fqname(self.namespace, self.name)
  end

  def domain
    ae_namespace.domain
  end

  def namespace
    return nil if self.ae_namespace.nil?
    return self.ae_namespace.fqname
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

  def self.get_homonymic_across_domains(fqname, enabled = nil)
    MiqAeDatastore.get_homonymic_across_domains(::MiqAeClass, fqname, enabled)
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

  private

  def scoped_methods(s)
    self.ae_methods.select { |m| m.scope == s }
  end

  def self.get_sorted_homonym_class_across_domains(ns = nil, klass)
    ns_obj = MiqAeNamespace.find_by_fqname(ns) unless ns.nil?
    partial_ns = ns_obj.nil? ? ns : remove_domain_from_fqns(ns)
    class_array = MiqAeDomain.order("priority DESC").pluck(:name).collect do |domain|
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
end
