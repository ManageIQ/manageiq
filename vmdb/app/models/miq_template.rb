class MiqTemplate < VmOrTemplate
  SUBCLASSES = %w{
    TemplateInfra
    TemplateCloud
  }

  default_scope where(:template => true)

  include_concern 'Operations'

  def self.base_model
    MiqTemplate
  end

  def self.model_suffix
    self == MiqTemplate ? "" : self.name[8..-1]
  end

  def self.corresponding_model
    @corresponding_model ||= "Vm#{self.model_suffix}".constantize
  end
  class << self; alias corresponding_vm_model corresponding_model; end

  def corresponding_model
    self.class.corresponding_model
  end
  alias corresponding_vm_model corresponding_model

  def scan_via_ems?
    true
  end

  def self.supports_kickstart_provisioning?
    false
  end

  def supports_kickstart_provisioning?
    self.class.supports_kickstart_provisioning?
  end

  def self.eligible_for_provisioning
    where(self.arel_table[:ems_id].not_eq(nil))
  end

  def active?; false; end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
MiqTemplate::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
