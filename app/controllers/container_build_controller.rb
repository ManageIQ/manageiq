class ContainerBuildController < ApplicationController
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def show_list
    process_show_list
  end

  private ############################

  def display_name
    "Builds"
  end

  menu_section :cnt
end
