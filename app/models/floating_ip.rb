class FloatingIp < ApplicationRecord
  include NewWithTypeStiMixin
  include SupportsFeatureMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  # Not going through network_port because of Amazon, old EC2 way allows to associate public Ip to instance, without
  # any network_port used
  belongs_to :vm
  belongs_to :cloud_tenant
  belongs_to :cloud_network
  belongs_to :network_port
  belongs_to :network_router

  def self.available
    where(:vm_id => nil, :network_port_id => nil)
  end

  def name
    address
  end

  def self.class_by_ems(ext_management_system)
    # TODO: use a factory on ExtManagementSystem side to return correct class for each provider
    ext_management_system && ext_management_system.class::FloatingIp
  end
end
