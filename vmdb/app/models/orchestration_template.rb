require 'digest/md5'
class OrchestrationTemplate < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  has_many :stacks, :class_name => "OrchestrationStack"

  # Find only by template content. Here we only compare md5 considering the table is expected
  # to be small and the chance of md5 collision is minimal.
  #
  def self.find_or_create_by_contents(hashes)
    hashes = [hashes] unless hashes.kind_of?(Array)
    ems_refs = hashes.collect { |hash| Digest::MD5.hexdigest(hash[:content]) }
    existing_templates = find_all_by_ems_ref(ems_refs).index_by(&:ems_ref)

    hashes.zip(ems_refs).collect do |hash, ems_ref|
      template = existing_templates[ems_ref]
      unless template
        hash.delete(:ems_ref)     # remove the field if exists, :ems_ref is read only from outside
        template = create(hash)
        existing_templates[ems_ref] = template
      end
      template
    end
  end

  def content=(c)
    super
    self.ems_ref = Digest::MD5.hexdigest(c)
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

  def ems_ref=(_md5)
    super
  end
end
