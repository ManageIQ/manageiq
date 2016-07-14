class ArbitrationProfile < ApplicationRecord
  validates :ext_management_system, :presence => true
  validates :name, :presence => true
  validate :falsify_all_others, :if => :default_profile_changed?

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :cloud_subnet
  belongs_to :cloud_network
  belongs_to :authentication
  belongs_to :flavor
  belongs_to :availability_zone
  belongs_to :security_group

  # If a record is updated as the default, falsify others
  def falsify_all_others
    self.class.where(:default_profile => true).where.not(:id => id).update_all(:default_profile => false)
  end
end
