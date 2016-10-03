class EmsInfraDashboardController < ApplicationController
  extend ActiveSupport::Concern

  before_action :check_privileges
  after_action :cleanup_action

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
end
