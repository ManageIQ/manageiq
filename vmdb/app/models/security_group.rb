class SecurityGroup < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :cloud_network
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack
  has_many   :firewall_rules, :as => :resource, :dependent => :destroy
  has_and_belongs_to_many :vms

  def total_vms
    vms.count
  end
  virtual_column :total_vms, :type => :integer, :uses => :vms

  def self.non_cloud_network
    where(:cloud_network_id => nil)
  end
end
