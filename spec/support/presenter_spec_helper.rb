module PresenterSpecHelper
  include ActionView::Helpers::JavaScriptHelper

  def login_as(user)
    User.current_user = user
    ActionController::TestSession.any_instance.stub(:userid).and_return(user.userid)
    ActionController::TestSession.any_instance.stub(:group).and_return(user.current_group.try(:id))
  end
end
