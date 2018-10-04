class ConversionHost < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :resource, :polymorphic => true
  has_many :service_template_transformation_plan_tasks, :dependent => :nullify
  has_many :active_tasks, -> { where(:state => 'active') }, :class_name => ServiceTemplateTransformationPlanTask

  def eligible?
    return true if concurrent_transformation_limit.nil?
    puts "Active tasks: #{active_tasks}"
    active_tasks.size < concurrent_transformation_limit.to_i
  end

  def source_transport_method
    return 'vddk' if vddk_transport_supported
    return 'ssh' if ssh_transport_supported
  end
end
