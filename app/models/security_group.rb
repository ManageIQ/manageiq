class SecurityGroup < ApplicationRecord
  include NewWithTypeStiMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_network
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack
  belongs_to :network_group
  belongs_to :cloud_subnet
  belongs_to :network_router
  has_many   :firewall_rules, :as => :resource, :dependent => :destroy

  has_many :network_port_security_groups, :dependent => :destroy
  has_many :network_ports, :through => :network_port_security_groups
  # TODO(lsmola) we should be able to remove table security_groups_vms, if it's unused now. Can't be backported
  has_many :vms, -> { distinct }, :through => :network_ports, :source => :device, :source_type => 'VmOrTemplate'

  virtual_total :total_vms, :vms, :uses => :vms

  def self.non_cloud_network
    where(:cloud_network_id => nil)
  end

  def self.class_by_ems(ext_management_system)
    # TODO: use a factory on ExtManagementSystem side to return correct class for each provider
    ext_management_system && ext_management_system.class::SecurityGroup
  end
end
