class OpenshiftDeploymentController < ApplicationController
  extend ActiveSupport::Concern

  # before_action :check_privileges
  after_action :cleanup_action

  def new
    @layout = 'openshift_deployment'
    if params[:id].nil?
      @breadcrumbs.clear
    end
  end

  def data
    render :json => {:data => collect_data}
  end

  private

  def get_session_data
    @layout = "container_dashboard"
  end

  def collect_data
    OpenshiftDeploymentService.new.all_data
  end

  def set_session_data
    session[:layout] = @layout
  end
end
