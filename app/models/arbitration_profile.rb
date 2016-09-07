class ArbitrationProfile < ArbitrationRecord
  default_scope { where(:profile => true) }

  def self.base_model
    ArbitrationProfile
  end

  validates :ext_management_system, :presence => true
  validates :name, :presence => true
  validate :falsify_all_others, :if => :default_profile_changed?

  default_value_for :default_profile, false
  default_value_for :profile, true

  # If a record is updated as the default, falsify others
  def falsify_all_others
    self.class.where(:default_profile => true).where.not(:id => id).update_all(:default_profile => false)
  end
end
