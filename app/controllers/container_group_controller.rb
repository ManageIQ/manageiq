class ContainerGroupController < ApplicationController
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def show_list
    process_show_list
  end

  def data
    render :json => {:data => collect_data(params[:id])}
  end

  private

  def collect_data(project_id)
    ContainerGroupDashboardService.new(project_id, self).all_data
  end

  def display_name
    "Pods"
  end
end
