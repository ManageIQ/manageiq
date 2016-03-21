class FloatingIp < ApplicationRecord
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  # TODO(lsmola) NetworkManager, once all providers use network manager rename this to "ManageIQ::Providers::NetworkManager"
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::BaseManager"
  # TODO(lsmola) NetworkManager, remove when all providers share the new network architecture
  belongs_to :vm
  belongs_to :cloud_tenant
  belongs_to :cloud_network
  belongs_to :network_port
  belongs_to :network_router

  def self.available
    where(:vm_id => nil)
  end

  def name
    address
  end
end
