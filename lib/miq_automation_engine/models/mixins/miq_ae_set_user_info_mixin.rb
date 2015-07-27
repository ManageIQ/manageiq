module MiqAeSetUserInfoMixin
  extend ActiveSupport::Concern
  included do
    before_validation  :set_user_info
  end

  def set_user_info
    self.updated_by         = User.current_userid || 'system'
    self.updated_by_user_id = User.current_user ? User.current_user.id : nil
  end

end
