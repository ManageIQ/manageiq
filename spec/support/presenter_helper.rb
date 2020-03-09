module Spec
  module Support
    module PresenterHelper
      include ActionView::Helpers::JavaScriptHelper

      def login_as(user)
        User.current_user = user
      end
    end
  end
end
