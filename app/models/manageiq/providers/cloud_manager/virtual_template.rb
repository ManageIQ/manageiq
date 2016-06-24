class ManageIQ::Providers::CloudManager::VirtualTemplate < ::MiqTemplate
  validate :validate_single_template, :on => :create
  default_value_for :cloud, true

  TYPES = {
    :amazon => 'ManageIQ::Providers::Amazon::CloudManager::VirtualTemplate'
  }.freeze

  def single_template?
    type.constantize.where(:type => type).empty?
  end

  def validate_single_template
    errors.add(:virtual_template, _('may only have one per type')) unless single_template?
  end
end
