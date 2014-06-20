require "rexml/document"
class MiqTemplateController < ApplicationController
  include VmCommon        # common methods for vm/vdi vm controllers

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    session[:miq_template_type] = nil             # Reset VM type if coming in from All tab
    redirect_to :action => 'show_list'
  end

  def show_list
    process_show_list
  end

  private

  def get_session_data
    @title          = "Templates"
    @layout         = session[:miq_template_type] ? session[:miq_template_type] : "miq_template"
    @lastaction     = session[:miq_template_lastaction]
    @showtype       = session[:miq_template_showtype]
    @base           = session[:miq_template_compare_base]
    @filters        = session[:miq_template_filters]
    @catinfo        = session[:miq_template_catinfo]
    @cats           = session[:miq_template_cats]
    @display        = session[:miq_template_display]
    @polArr         = session[:polArr] == nil ? "" : session[:polArr]           # current tags in effect
    @policy_options = session[:policy_options] == nil ? "" : session[:policy_options]
  end

  def set_session_data
    session[:miq_template_lastaction]   = @lastaction
    session[:miq_template_showtype]     = @showtype
    session[:miq_compressed]            = @compressed if @compressed != nil
    session[:miq_exists_mode]           = @exists_mode if @exists_mode != nil
    session[:miq_template_compare_base] = @base
    session[:miq_template_filters]      = @filters
    session[:miq_template_catinfo]      = @catinfo
    session[:miq_template_cats]         = @cats
    session[:miq_template_display]      = @display unless @display.nil?
    session[:polArr]                    = @polArr if @polArr != nil
    session[:policy_options]            = @policy_options if @policy_options != nil
  end

end
