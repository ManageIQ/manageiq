class EmsCloudController < ApplicationController
  include EmsCommon        # common methods for EmsInfra/Cloud controllers

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def self.model
    @model ||= EmsCloud
  end

  def self.table_name
    @table_name ||= "ems_cloud"
  end

  def index
    redirect_to :action => 'show_list'
  end

  private ############################

  def get_session_data
    @title      = ui_lookup(:tables => "ems_cloud")
    @layout     = "ems_cloud"
    @table_name = request.parameters[:controller]
    @model      = EmsCloud
    @lastaction = session[:ems_cloud_lastaction]
    @display    = session[:ems_cloud_display]
    @filters    = session[:ems_cloud_filters]
    @catinfo    = session[:ems_cloud_catinfo]
  end

  def set_session_data
    session[:ems_cloud_lastaction] = @lastaction
    session[:ems_cloud_display]    = @display unless @display.nil?
    session[:ems_cloud_filters]    = @filters
    session[:ems_cloud_catinfo]    = @catinfo
  end
end
