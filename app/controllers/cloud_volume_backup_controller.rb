class CloudVolumeBackupController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh
    return tag("CloudVolumeBackup") if params[:pressed] == 'cloud_volume_backup_tag'
    if @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render_flash
    end
  end

  def show
    @display = params[:display] || "main" unless control_selected?
    @showtype = @display
    @lastaction = "show"

    @backup = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@backup)

    @gtl_url = "/show"
    drop_breadcrumb(
      {
        :name => ui_lookup(:tables => 'cloud_volume_backup'),
        :url  => "/cloud_volume_backup/show_list?page=#{@current_page}&refresh=y"
      },
      true
    )

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@backup)
      drop_breadcrumb(
        :name => _("%{name} (Summary)") % {:name => @backup.name},
        :url  => "/cloud_volume_backup/show/#{@backup.id}"
      )
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    end

    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  # Show the main Cloud Volume Backup list view
  def show_list
    process_show_list
  end

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
end
