class ManageIQ::Providers::CloudManager::VirtualTemplate < ArbitrationRecord
  default_scope { where(:profile => false) }

  validates :ext_management_system, :presence => true

  default_value_for :profile, false
end
