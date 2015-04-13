class ContainerNodeController < ApplicationController
  include ContainersCommonMixin

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def show_list
    @no_checkboxes = true
    process_show_list
  end

  private ############################

  def controller_name
    "container_node"
  end

  def display_name
    "Container Nodes"
  end
end
