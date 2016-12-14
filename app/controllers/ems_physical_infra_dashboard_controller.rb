class EmsPhysicalInfraDashboardController < ApplicationController
  extend ActiveSupport::Concern

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def show
    if params[:id].nil?
      @breadcrumbs.clear
    end
  end

  def data
    render :json => {:data => collect_data(params[:id])}
  end

  private

  def collect_data(ems_id)
    EmsInfraDashboardService.new(ems_id, self).all_data
  end

  def get_session_data
    @layout = "ems_infra_dashboard"
  end

  def set_session_data
    session[:layout] = @layout
  end
end
