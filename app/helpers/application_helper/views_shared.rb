module ApplicationHelper
  module ViewsShared
    # Methods here are only used from app/views/shared
    # Other methods from ApplicationHelper might be used from controllers as well.
    include Dialogs
    include Discover
    include FormTags
  end

  def ownership_user_options
    @ownership_users ||= Rbac.filtered(User).each_with_object({}) { |u, r| r[u.name] = u.id.to_s }
  end
end
