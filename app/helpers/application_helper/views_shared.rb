module ApplicationHelper
  module ViewsShared
    # Methods here are only used from app/views/shared
    # Other methods from ApplicationHelper might be used from controllers as well.
    include Dialogs
    include Discover
    include FormTags
  end
end
