require 'digest/md5'
class OrchestrationTemplate < ApplicationRecord
  TEMPLATE_DIR = Rails.root.join("product/orchestration_templates")

  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  has_many :stacks, :class_name => "OrchestrationStack"

  default_value_for :draft, false
  default_value_for :orderable, true

  validates :md5,
            :uniqueness => {:scope => :draft, :message => "of content already exists (content must be unique)"},
            :unless     => :draft?
  validates_presence_of :name

  before_destroy :check_not_in_use

  # Try to create the template if the name is not found in table
  def self.seed
    Dir.glob(TEMPLATE_DIR.join('*.yml')).each do |file|
      hash = YAML.load_file(file)
      next if hash[:type].constantize.find_by(:name => hash[:name])
      find_or_create_by_contents(hash)
    end
  end

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
        md5s << calc_md5(with_universal_newline(hash[:content]))
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

  def parameter_groups
    raise NotImplementedError, "parameter_groups must be implemented in subclass"
  end

  # List managers that may be able to deploy this template
  def self.eligible_managers
    ExtManagementSystem.where(:type => eligible_manager_types.collect(&:name))
  end

  delegate :eligible_managers, :to => :class

  # return the validation error message; otherwise nil
  def validate_content(manager = nil)
    test_managers = manager.nil? ? eligible_managers : [manager]
    test_managers.each do |mgr|
      return mgr.orchestration_template_validate(self) rescue nil
    end
    "No #{ui_lookup(:model => 'ExtManagementSystem').downcase} is capable to validate the template"
  end

  def validate_format
    raise NotImplementedError, "validate_format must be implemented in subclass"
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
    return save! if old_template.nil? || old_template.orderable

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
