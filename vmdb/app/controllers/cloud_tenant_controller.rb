class CloudTenantController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show_list
    process_show_list
  end

  private

  def get_session_data
    @title      = "Cloud Tenant"
    @layout     = "cloud_tenant"
    @lastaction = session[:cloud_tenant_lastaction]
    @display    = session[:cloud_tenant_display]
    @filters    = session[:cloud_tenant_filters]
    @catinfo    = session[:cloud_tenant_catinfo]
  end

  def set_session_data
    session[:cloud_tenant_lastaction] = @lastaction
    session[:cloud_tenant_display]    = @display unless @display.nil?
    session[:cloud_tenant_filters]    = @filters
    session[:cloud_tenant_catinfo]    = @catinfo
  end
end
