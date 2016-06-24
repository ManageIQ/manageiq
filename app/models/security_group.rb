class SecurityGroup < ApplicationRecord
  include NewWithTypeStiMixin
  include VirtualTotalMixin

  acts_as_miq_taggable

  # TODO(lsmola) NetworkManager, once all providers use network manager rename this to
  # "ManageIQ::Providers::NetworkManager"
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::BaseManager"
  belongs_to :cloud_network
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack
  belongs_to :network_group
  has_many   :firewall_rules, :as => :resource, :dependent => :destroy

  has_and_belongs_to_many :vms
  has_and_belongs_to_many :network_ports

  virtual_total :total_vms, :vms, :arel => nil

  def self.non_cloud_network
    where(:cloud_network_id => nil)
  end
end
