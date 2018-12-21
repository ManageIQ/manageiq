require 'digest/md5'
class OrchestrationTemplate < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  has_many :stacks, :class_name => "OrchestrationStack"
  has_one :picture, :dependent => :destroy, :as => :resource, :autosave => true

  default_value_for :draft, false
  default_value_for :orderable, true

  validates :md5,
            :uniqueness => {:scope => :draft, :message => "of content already exists (content must be unique)"},
            :if         => :unique_md5?
  validates_presence_of :name

  scope :orderable, -> { where(:orderable => true) }

  before_destroy :check_not_in_use

  attr_accessor :remote_proxy
  alias remote_proxy? remote_proxy

  # available templates for ordering an orchestration service
  def self.available
    where(:draft => false, :orderable => true)
  end

  def self.find_with_content(template_content)
    where(:draft => false).find_by(:md5 => calc_md5(with_universal_newline(template_content)))
  end

  # Find only by template content. Here we only compare md5 considering the table is expected
  # to be small and the chance of md5 collision is minimal.
  #
  def self.find_or_create_by_contents(hashes)
    hashes = [hashes] unless hashes.kind_of?(Array)
    md5s = []
    hashes = hashes.reject do |hash|
      if hash[:draft]
        create!(hash.except(:md5)) # always create a new template if it is a draft
        true
      else
        klass = hash[:type].present? ? hash[:type].constantize : self
        md5s << klass.calc_md5(with_universal_newline(hash[:content]))
        false
      end
    end

    existing_templates = where(:draft => false, :md5 => md5s).index_by(&:md5)

    hashes.zip(md5s).collect do |hash, md5|
      template = existing_templates[md5]
      unless template
        template = create!(hash.except(:md5))
        existing_templates[md5] = template
      end
      template
    end
  end

  def content=(text)
    super(with_universal_newline(text))
    self.md5 = calc_md5(content)
  end

  # Determines if validation for md5 uniqueness is done
  def unique_md5?
    !draft?
  end

  # Check whether a template has been referenced by any stack. A template that is in use should be
  # considered read only
  def in_use?
    !stacks.empty?
  end

  # Find all in use and read-only templates
  def self.in_use
    joins(:stacks).distinct
  end

  # Find all not in use thus editable templates
  def self.not_in_use
    includes(:stacks).where(:orchestration_stacks => {:orchestration_template_id => nil})
  end

  def tabs
    [
      {
        :title        => "Basic Information",
        :stack_group  => deployment_options,
        :param_groups => parameter_groups
      }
    ]
  end

  def parameter_groups
    raise NotImplementedError, _("parameter_groups must be implemented in subclass")
  end

  # Basic options for all templates, each subclass should add more type/provider specific deployment options
  # Return array of OrchestrationParameters. (Deployment options are different from parameters, but they use same class)
  def deployment_options(_manager_class = nil)
    stack_name_opt = OrchestrationTemplate::OrchestrationParameter.new(
      :name           => "stack_name",
      :label          => "Stack Name",
      :data_type      => "string",
      :description    => "Name of the stack",
      :required       => true,
      :reconfigurable => false,
      :constraints    => [
        OrchestrationTemplate::OrchestrationParameterPattern.new(
          :pattern => '^[A-Za-z][A-Za-z0-9\-]*$'
        )
      ]
    )
    [stack_name_opt]
  end

  # List managers that may be able to deploy this template
  def self.eligible_managers
    Rbac::Filterer.filtered(ExtManagementSystem, :named_scope => [[:with_eligible_manager_types, eligible_manager_types]])
  end

  delegate :eligible_managers, :to => :class

  def self.stack_type
    "OrchestrationStack"
  end

  delegate :stack_type, :to => :class

  # return the validation error message; otherwise nil
  def validate_content(manager = nil)
    test_managers = manager.nil? ? eligible_managers : [manager]
    test_managers.each do |mgr|
      return mgr.orchestration_template_validate(self) rescue nil
    end
    "No provider is capable to validate the template"
  end

  def validate_format
    raise NotImplementedError, _("validate_format must be implemented in subclass")
  end

  # use cases for md5 conflict:
  # draft: always save, new or existing
  # existing:
  #   discovered duplicate: take over stacks and delete the discovered one
  #   orderable duplicate: raise error through save! validation
  # new:
  #   discovered duplicate: promote discovered to orderable
  #   orderable duplicate: raise error through save! validation)
  def save_as_orderable!
    error_msg = validate_format unless draft
    raise MiqException::MiqParsingError, error_msg if error_msg

    self.orderable = true
    return save! if draft?

    old_template = self.class.find_with_content(content)
    return save! if old_template.nil? || old_template.orderable || old_template.id == id

    new_record? ? replace_with_old_template(old_template) : transfer_stacks(old_template)
  end

  private

  # This is an unsaved template. Replace with an existing one after it is updated
  def replace_with_old_template(old_template)
    old_template.update(:name => name, :description => description, :orderable => true)
    self.id = old_template.id
    reload
    true
  end

  # Take over stacks belongs to the old template and delete the old template
  def transfer_stacks(old_template)
    old_template.stacks.update_all(:orchestration_template_id => id)
    old_template.delete
    save!
  end

  def md5=(_md5)
    super
  end

  def self.calc_md5(text)
    Digest::MD5.hexdigest(text) if text
  end

  def calc_md5(text)
    self.class.calc_md5(text)
  end

  def self.with_universal_newline(text)
    # ensure universal new lines and content ending with a new line
    text.encode(:universal_newline => true).chomp.concat("\n")
  end

  def with_universal_newline(text)
    self.class.with_universal_newline(text)
  end

  def check_not_in_use
    return true unless in_use?
    errors[:base] << "Cannot delete the template while it is used by some orchestration stacks"
    throw :abort
  end
end
