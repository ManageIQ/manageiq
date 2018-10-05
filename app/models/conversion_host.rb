class ConversionHost < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :resource, :polymorphic => true
  has_many :service_template_transformation_plan_tasks, :dependent => :nullify
  has_many :active_tasks, -> { where(:state => 'active') }, :class_name => ServiceTemplateTransformationPlanTask, :inverse_of => :conversion_host

  # To be eligible, a conversion host must have the following properties
  #  - A transport mechanism is configured for source (set by 3rd party)
  #  - Credentials are set on the resource
  #  - The number of concurrent tasks has not reached the limit
  def eligible?
    source_transport_method.present? && check_resource_credentials && check_concurrent_tasks
  end

  def check_concurrent_tasks
    max_tasks = max_concurrent_tasks || Settings.transformation.limits.max_concurrent_tasks_per_host
    active_tasks.size < max_tasks
  end

  def check_resource_credentials
    send("check_resource_credentials_#{resource.ext_management_system.emstype}")
  end

  def source_transport_method
    return 'vddk' if vddk_transport_supported
    return 'ssh' if ssh_transport_supported
  end

  private

  def check_resource_credentials_rhevm
    !(resource.authentication_userid.nil? || resource.authentication_password.nil?)
  end

  def check_resource_credentials_openstack
    ssh_authentications = resource.ext_management_system.authentications
                                  .where(:authtype => 'ssh_keypair')
                                  .where.not(:userid => nil, :auth_key => nil)
    !ssh_authentications.empty?
  end
end
