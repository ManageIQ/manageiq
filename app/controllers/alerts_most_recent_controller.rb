class AlertsMostRecentController < ApplicationController
  extend ActiveSupport::Concern

  before_action :check_privileges
  before_action :session_data
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
    render :json => {:data => collect_data}
  end

  private

  def session_data
    @layout = "alerts_most_recent"
  end

  def collect_data
    AlertsService.new(self).all_data
  end

  def set_session_data
    session[:layout] = @layout
  end
end
