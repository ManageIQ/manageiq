class VmController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data
  include VmCommon        # common methods for vm controllers

  def index
    session[:vm_type] = nil             # Reset VM type if coming in from All tab
    redirect_to :action => 'show_list'
  end

  def show_list
    process_show_list(:association => session[:vm_type])
  end

  private ####

  def get_session_data
    @title          = _("Virtual Machines")
    @layout         = "vm"
    @lastaction     = session[:vm_lastaction]
    @showtype       = session[:vm_showtype]
    @base           = session[:vm_compare_base]
    @filters        = session[:vm_filters]
    @catinfo        = session[:vm_catinfo]
    @cats           = session[:vm_cats]
    @display        = session[:vm_display]
    @polArr         = session[:polArr] || ""           # current tags in effect
    @policy_options = session[:policy_options] || ""
  end

  def set_session_data
    session[:vm_lastaction]   = @lastaction
    session[:vm_showtype]     = @showtype
    session[:miq_compressed]  = @compressed unless @compressed.nil?
    session[:miq_exists_mode] = @exists_mode unless @exists_mode.nil?
    session[:vm_compare_base] = @base
    session[:vm_filters]      = @filters
    session[:vm_catinfo]      = @catinfo
    session[:vm_cats]         = @cats
    session[:vm_display]      = @display unless @display.nil?
    session[:polArr]          = @polArr unless @polArr.nil?
    session[:policy_options]  = @policy_options unless @policy_options.nil?
  end
end
