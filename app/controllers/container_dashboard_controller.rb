class ContainerDashboardController < ApplicationController
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

  def index
    redirect_to :action => 'show'
  end

  def data
    return data_live if params[:live] == 'true'
    render :json => {:data => collect_data(params[:id])}
  end

  def data_live
    render :json => collect_live_data(params[:id], params[:query])
  end

  private

  def get_session_data
    @layout = "container_dashboard"
  end

  def collect_data(provider_id)
    ContainerDashboardService.new(provider_id, self).all_data
  end

  def collect_live_data(provider_id, query)
    HawkularProxyService.new(provider_id, self).data(query)
  end

  def set_session_data
    session[:layout] = @layout
  end

  menu_section :cnt
end
