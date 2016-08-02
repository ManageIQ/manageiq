class ManageIQ::Providers::CloudManager::VirtualTemplate < ArbitrationProfile
  validates :ext_management_system, :presence => true

  default_value_for :profile, false
end
