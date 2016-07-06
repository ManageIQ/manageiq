class ManageIQ::Providers::CloudManager::VirtualTemplate < ::MiqTemplate
  validate :validate_single_template, :on => :create
  validates :ext_management_system, :presence => true

  default_value_for :cloud, true

  def single_template?
    type.constantize.where(:type => type).empty?
  end

  def validate_single_template
    errors.add(:virtual_template, _('may only have one per type')) unless single_template?
  end

  # TODO: take in a name for the VM
  def vm_fields
    {
      'placement_auto' => false,
      'placement_availability_zone' => availability_zone_id,
      'cloud_network'               => cloud_network_id,
      'cloud_subnet'                => cloud_subnet_id,
      'number_of_vms' => 1,
      'retirement' => 0,
      'vm_name' => 'arandomname',
      'boot_disk_size' => "10.GB",
      'instance_type' => flavor_id
    }
  end

  def template_fields
    {
      'guid' => guid,
      'name' => name,
      'request_type' => 'template'.freeze
     }
  end
end
