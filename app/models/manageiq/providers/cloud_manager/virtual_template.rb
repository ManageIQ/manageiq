class ManageIQ::Providers::CloudManager::VirtualTemplate < ::MiqTemplate
  # TODO: Some of these might not be generic, and will have to be provider-specific
  validates :cloud_network_id, :cloud_subnet_id, :availability_zone_id, :ems_ref, presence: true
  default_value_for :cloud, true

  def self.eligible_for_provisioning
    super.where(:type => %w(ManageIQ::Providers::Amazon::CloudManager::VirtualTemplate))
  end
end