module MiqAeSetUserInfoMixin
  extend ActiveSupport::Concern
  included do
    before_validation :set_user_info, :if => :user_info_changed?
  end

  def set_user_info
    self.updated_by         = User.current_userid || 'system'
    self.updated_by_user_id = User.current_user.try(:id)
  end

  def user_info_changed?
    updated_by_changed? || updated_by_user_id_changed? || new_record?
  end
end
