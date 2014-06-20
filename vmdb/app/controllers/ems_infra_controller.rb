class EmsInfraController < ApplicationController
  include EmsCommon        # common methods for EmsInfra/Cloud controllers

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def self.model
    @model ||= EmsInfra
  end

  def self.table_name
    @table_name ||= "ems_infra"
  end

  def index
    redirect_to :action => 'show_list'
  end

  private ############################

  def get_session_data
    @title      = ui_lookup(:tables => "ems_infra")
    @layout     = "ems_infra"
    @table_name = request.parameters[:controller]
    @model      = EmsInfra
    @lastaction = session[:ems_infra_lastaction]
    @display    = session[:ems_infra_display]
    @filters    = session[:ems_infra_filters]
    @catinfo    = session[:ems_infra_catinfo]
  end

  def set_session_data
    session[:ems_infra_lastaction] = @lastaction
    session[:ems_infra_display]    = @display unless @display.nil?
    session[:ems_infra_filters]    = @filters
    session[:ems_infra_catinfo]    = @catinfo
  end
end
