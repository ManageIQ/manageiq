module Spec
  module Support
    module PresenterHelper
      include ActionView::Helpers::JavaScriptHelper

      def login_as(user)
        User.current_user = user
        allow_any_instance_of(ActionController::TestSession).to receive(:userid).and_return(user.userid)
        allow_any_instance_of(ActionController::TestSession).to receive(:group).and_return(user.current_group.try(:id))
      end
    end
  end
end
