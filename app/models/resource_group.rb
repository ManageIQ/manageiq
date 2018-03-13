class ResourceGroup < ApplicationRecord
  acts_as_miq_taggable
  alias_attribute :images, :templates

  has_many :vm_or_templates

  # Rely on default scopes to get expected information
  has_many :vms, :class_name => 'Vm'
  has_many :templates, :class_name => 'MiqTemplate'
end
