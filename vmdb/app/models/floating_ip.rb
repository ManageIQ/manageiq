class FloatingIp < ActiveRecord::Base
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "Ems::CloudProvider"
  belongs_to :vm
  belongs_to :cloud_tenant

  def self.available
    where(:vm_id => nil)
  end
end
