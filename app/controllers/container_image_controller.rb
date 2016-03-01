class ContainerImageController < ApplicationController
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def guest_applications
    show_association('guest_applications', _('Packages'), 'guest_application', :guest_applications, GuestApplication)
  end

end
