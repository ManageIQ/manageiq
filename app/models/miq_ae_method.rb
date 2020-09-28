require 'manageiq/automation_engine/syntax_checker'

class MiqAeMethod < ApplicationRecord
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin
  include RelativePathMixin

  default_value_for(:embedded_methods) { [] }
  validates :embedded_methods, :exclusion => { :in => [nil] }
  serialize :options, Hash
  before_validation :set_relative_path

  belongs_to :domain, :class_name => "MiqAeDomain", :inverse_of => false
  belongs_to :ae_class, :class_name => "MiqAeClass", :foreign_key => :class_id
  has_many   :inputs,   -> { order(:priority) }, :class_name => "MiqAeField", :foreign_key => :method_id,
                        :dependent => :destroy, :autosave => true

  validates :scope, :domain_id, :class_id, :presence => true
  validates :name,  :presence                => true,
                    :uniqueness_when_changed => {:case_sensitive => false, :scope => [:class_id, :scope]},
                    :format                  => {:with    => /\A[\w]+\z/i,
                                                 :message => N_("may contain only alphanumeric and _ characters")}

  AVAILABLE_LANGUAGES  = ["ruby", "perl"]  # someday, add sh, perl, python, tcl and any other scripting language
  validates_inclusion_of  :language,  :in => AVAILABLE_LANGUAGES
  AVAILABLE_LOCATIONS = %w(builtin inline expression playbook ansible_job_template ansible_workflow_template).freeze
  validates_inclusion_of  :location,  :in => AVAILABLE_LOCATIONS
  AVAILABLE_SCOPES     = ["class", "instance"]
  validates_inclusion_of  :scope,     :in => AVAILABLE_SCOPES

  def self.available_languages
    AVAILABLE_LANGUAGES
  end

  def self.available_locations
    AVAILABLE_LOCATIONS
  end

  def self.available_scopes
    AVAILABLE_SCOPES
  end

  def self.available_expression_objects
    MiqExpression.base_tables
  end

  # Validate the syntax of the passed in inline ruby code
  def self.validate_syntax(code_text)
    result = ManageIQ::AutomationEngine::SyntaxChecker.check(code_text)
    return nil if result.valid?
    [[result.error_line, result.error_text]] # Array of arrays for future multi-line support
  end

  # my method's fqname is /domain/namespace1/namespace2/class/method
  def namespace
    fqname.split("/")[0..-3].join("/")
  end

  def self.default_method_text
    <<-DEFAULT_METHOD_TEXT
#
# Description: <Method description here>
#
    DEFAULT_METHOD_TEXT
  end

  def to_export_yaml
    export_attributes.tap do |hash|
      hash.delete('options') if options.empty?
      hash.delete('embedded_methods') if embedded_methods.empty?
    end
  end

  def method_inputs
    inputs.collect(&:to_export_yaml)
  end

  def to_export_xml(options = {})
    require 'builder'
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml_attrs = {:name => name, :language => language, :scope => scope, :location => location}

    self.class.column_names.each do |cname|
      # Remove any columns that we do not want to export
      next if %w(id created_on updated_on updated_by).include?(cname) || cname.ends_with?("_id")

      # Skip any columns that we process explicitly
      next if %w(name language scope location data).include?(cname)

      # Process the column
      xml_attrs[cname.to_sym]  = send(cname)   unless send(cname).blank?
    end

    xml.MiqAeMethod(xml_attrs) do
      xml.target!.chomp!
      xml << "<![CDATA[#{data}]]>"
      inputs.each { |i| i.to_export_xml(:builder => xml) }
    end
  end

  delegate :editable?, :to => :ae_class

  def field_names
    inputs.collect { |f| f.name.downcase }
  end

  def field_value_hash(name)
    field = inputs.detect { |f| f.name.casecmp(name) == 0 }
    raise "Field #{name} not found in method #{self.name}" if field.nil?
    field.attributes
  end

  def self.copy(options)
    if options[:new_name]
      MiqAeMethodCopy.new(options[:fqname]).as(options[:new_name],
                                               options[:namespace],
                                               options[:overwrite_location]
                                              )
    else
      MiqAeMethodCopy.copy_multiple(options[:ids],
                                    options[:domain],
                                    options[:namespace],
                                    options[:overwrite_location]
                                   )
    end
  end

  def self.get_homonymic_across_domains(user, fqname, enabled = nil)
    MiqAeDatastore.get_homonymic_across_domains(user, ::MiqAeMethod, fqname, enabled)
  end

  def self.lookup_by_class_id_and_name(class_id, name)
    ae_method_filter = ::MiqAeMethod.arel_table[:name].lower.matches(name.downcase, nil, true)
    ::MiqAeMethod.where(ae_method_filter).where(:class_id => class_id).first
  end

  singleton_class.send(:alias_method, :find_by_class_id_and_name, :lookup_by_class_id_and_name)
  Vmdb::Deprecation.deprecate_methods(singleton_class, :find_by_class_id_and_name => :lookup_by_class_id_and_name)

  def self.display_name(number = 1)
    n_('Automate Method', 'Automate Methods', number)
  end

  def self.find_best_match_by(user, relative_path)
    domain_ids = user.current_tenant.enabled_domains
    joins(:domain).where(:miq_ae_namespaces => {:id => domain_ids})
                  .order("miq_ae_namespaces.priority DESC")
                  .find_by(arel_table[:relative_path].lower.matches(relative_path.downcase, nil, true))
  end

  private

  def set_relative_path
    self.domain_id ||= ae_class&.domain_id
    self.relative_path = "#{ae_class.relative_path}/#{name}" if (name_changed? || relative_path_changed?) && ae_class
  end
end
