class CloudVolumeBackupController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin
  include Mixins::GenericShowMixin
  include Mixins::GenericButtonMixin

  private

  def get_session_data
    @title      = ui_lookup(:table => 'cloud_volume_backup')
    @layout     = "cloud_volume_backup"
    @lastaction = session[:cloud_volume_backup_lastaction]
    @display    = session[:cloud_volume_backup_display]
    @filters    = session[:cloud_volume_backup_filters]
    @catinfo    = session[:cloud_volume_backup_catinfo]
    @showtype   = session[:cloud_volume_backup_showtype]
  end

  def set_session_data
    session[:cloud_volume_backup_lastaction] = @lastaction
    session[:cloud_volume_backup_display]    = @display unless @display.nil?
    session[:cloud_volume_backup_filters]    = @filters
    session[:cloud_volume_backup_catinfo]    = @catinfo
    session[:cloud_volume_backup_showtype]   = @showtype
  end

  menu_section :bst
end
