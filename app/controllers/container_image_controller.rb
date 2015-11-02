class ContainerImageController < ApplicationController
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def show_list
    process_show_list
  end

  def guest_applications
    show_association('guest_applications', 'Packages', 'guest_application', :guest_applications, GuestApplication)
  end

  private ############################

  def display_name
    "Container Images"
  end
end
