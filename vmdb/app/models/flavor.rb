class Flavor < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "Ems::CloudProvider"
  has_many   :vms

  virtual_column :total_vms, :type => :integer, :uses => :vms

  default_value_for :enabled, true

  def total_vms
    vms.size
  end
end
