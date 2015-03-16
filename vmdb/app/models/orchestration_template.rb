require 'digest/md5'
class OrchestrationTemplate < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  has_many :stacks, :class_name => "OrchestrationStack"

  default_value_for :draft, false

  validates :md5, :uniqueness => {:scope => :draft}, :unless => :draft?

  def self.available
    where(:draft => false)
  end

  def self.find_with_content(template_content)
    available.where(:md5 => calc_md5(template_content)).first
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
                 md5s << calc_md5(hash[:content])
                 false
               end
             end

    existing_templates = available.where(:md5 => md5s).index_by(&:md5)

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
    super
    self.md5 = calc_md5(text)
  end

  # Check whether a template has been referenced by any stack. A template that is in use should be
  # considered read only
  def in_use?
    !stacks.empty?
  end

  # Find all in use and read-only templates
  def self.in_use
    joins(:stacks).uniq
  end

  # Find all not in use thus editable templates
  def self.not_in_use
    includes(:stacks).where(OrchestrationStack.arel_table[:orchestration_template_id].eq(nil))
  end

  def parameter_groups
    raise NotImplementedError, "parameter_groups must be implemented in subclass"
  end

  # List managers that may be able to deploy this template
  def self.eligible_managers
    ExtManagementSystem.where(:type => eligible_manager_types.collect(&:name))
  end

  def eligible_managers
    self.class.eligible_managers
  end

  # return the validation error message; otherwise nil
  def validate_content(manager = nil)
    test_managers = manager.nil? ? eligible_managers : [manager]
    test_managers.each do |mgr|
      return mgr.orchestration_template_validate(self) rescue nil
    end
    "No #{ui_lookup(:model => 'ExtManagementSystem').downcase} is capable to validate the template"
  end

  private

  def md5=(_md5)
    super
  end

  def self.calc_md5(text)
    Digest::MD5.hexdigest(text) if text
  end

  def calc_md5(text)
    self.class.calc_md5(text)
  end
end
