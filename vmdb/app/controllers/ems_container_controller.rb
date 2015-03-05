class EmsContainerController < ApplicationController
  include EmsCommon        # common methods for EmsInfra/Cloud/Container controllers

  #before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def self.model
    @model ||= EmsContainer
  end

  def self.table_name
    @table_name ||= "ems_container"
  end

  def index
    redirect_to :action => 'show_list'
  end

  private ############################

  def get_session_data
    @title      = ui_lookup(:tables => "ems_container")
    @layout     = "ems_container"
    @table_name = request.parameters[:controller]
    @model      = EmsContainer
    @lastaction = session[:ems_container_lastaction]
    @display    = session[:ems_container_display]
    @filters    = session[:ems_container_filters]
    @catinfo    = session[:ems_container_catinfo]
  end

  def set_session_data
    session[:ems_container_lastaction] = @lastaction
    session[:ems_container_display]    = @display unless @display.nil?
    session[:ems_container_filters]    = @filters
    session[:ems_container_catinfo]    = @catinfo
  end
end
