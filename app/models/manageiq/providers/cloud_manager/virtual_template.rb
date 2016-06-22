class ManageIQ::Providers::CloudManager::VirtualTemplate < ::MiqTemplate
  validate :single_template, on: :create
  default_value_for :cloud, true

  TYPES = {
      amazon: 'ManageIQ::Providers::Amazon::CloudManager::VirtualTemplate'
  }

  def single_template
    single = type.constantize.where(type: type).size > 0
    errors.add(:virtual_template, 'may only have one per type') if single
    single
  end
end