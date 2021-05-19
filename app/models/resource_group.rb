class ResourceGroup < ApplicationRecord
  acts_as_miq_taggable
  alias_attribute :images, :templates

  belongs_to :ext_management_system, :foreign_key => :ems_id

  has_many :vm_or_templates

  # Rely on default scopes to get expected information
  has_many :vms, :class_name => 'Vm', :dependent => :nullify
  has_many :templates, :class_name => 'MiqTemplate'

  has_many :cloud_networks, :dependent => :nullify
  has_many :network_ports, :dependent => :nullify
  has_many :security_groups, :dependent => :nullify
end
