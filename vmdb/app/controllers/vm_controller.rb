class VmController < ApplicationController
  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data
  include VmCommon        # common methods for vm/vdi vm controllers

  def index
    session[:vm_type] = nil             # Reset VM type if coming in from All tab
    redirect_to :action => 'show_list'
  end

  def show_list
    process_show_list({:association=>session[:vm_type]})
  end

  private ####

  def get_session_data
    @title = "Virtual Machines"
    @layout = "vm"
    @lastaction = session[:vm_lastaction]
    @showtype = session[:vm_showtype]
    @base = session[:vm_compare_base]
    @filters = session[:vm_filters]
    @catinfo = session[:vm_catinfo]
    @cats = session[:vm_cats]
    @display = session[:vm_display]
    @polArr = session[:polArr] == nil ? "" : session[:polArr]           # current tags in effect
    @policy_options = session[:policy_options] == nil ? "" : session[:policy_options]
  end

  def set_session_data
    session[:vm_lastaction] = @lastaction
    session[:vm_showtype] = @showtype
    session[:miq_compressed] = @compressed if @compressed != nil
    session[:miq_exists_mode] = @exists_mode if @exists_mode != nil
    session[:vm_compare_base] = @base
    session[:vm_filters] = @filters
    session[:vm_catinfo] = @catinfo
    session[:vm_cats] = @cats
    session[:vm_display] = @display == nil ? session[:vm_display] : @display
    session[:polArr] = @polArr if @polArr != nil
    session[:policy_options] = @policy_options if @policy_options != nil
  end

end

