class ConversionHost < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :resource, :polymorphic => true
  has_many :service_template_transformation_plan_tasks, :dependent => :nullify

  def active_tasks
    service_template_transformation_plan_tasks { active }
  end

  def eligible?
    return true if concurrent_transformation_limit.nil?
    active_tasks.size < concurrent_transformation_limit.to_i
  end

  def source_transport_method
    return 'vddk' if vddk_transport_supported
    return 'ssh' if ssh_transport_supported
  end
end
