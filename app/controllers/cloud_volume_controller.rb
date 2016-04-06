class CloudVolumeController < ApplicationController
  include AuthorizationMessagesMixin
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
    params[:display] = @display if %w(vms instances images).include?(@display)
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh
    return tag("CloudVolume") if params[:pressed] == 'cloud_volume_tag'
  end

  def show
    @display = params[:display] || "main" unless control_selected?
    @showtype = @display
    @lastaction = "show"

    @volume = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@volume)

    @gtl_url = "/show"
    drop_breadcrumb({:name => _("Cloud Volumes"), :url => "/cloud_volume/show_list?page=#{@current_page}&refresh=y"}, true)

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@volume)
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => @volume.name.to_s}, :url => "/cloud_volume/show/#{@volume.id}")
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    when "cloud_volume_snapshots"
      title = ui_lookup(:tables => 'cloud_volume_snapshots')
      kls   = CloudVolumeSnapshot
      drop_breadcrumb(
        :name => _("%{name} (All %{children})") % {:name => @volume.name, :children => title},
        :url  => "/cloud_volume/show/#{@volume.id}?display=cloud_volume_snapshots"
      )
      @view, @pages = get_view(kls, :parent => @volume, :association => :cloud_volume_snapshots)
      @showtype = "cloud_volume_snapshots"
      notify_about_unauthorized_items(title, ui_lookup(:tables => "cloud_volume"))
    when "instances"
      title = ui_lookup(:tables => "vm_cloud")
      kls   = ManageIQ::Providers::CloudManager::Vm
      drop_breadcrumb(
        :name => _("%{name} (All %{title})") % {:name => @volume.name, :title => title},
        :url  => "/cloud_volume/show/#{@volume.id}?display=#{@display}"
      )
      @view, @pages = get_view(kls, :parent => @volume) # Get the records (into a view) and the paginator
      @showtype = @display
      notify_about_unauthorized_items(title, ui_lookup(:tables => "cloud_volume"))
    end

    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  # Show the main Cloud Volume list view
  def show_list
    process_show_list
  end

  private

  def get_session_data
    @title      = ui_lookup(:table => 'cloud_volume')
    @layout     = "cloud_volume"
    @lastaction = session[:cloud_volume_lastaction]
    @display    = session[:cloud_volume_display]
    @filters    = session[:cloud_volume_filters]
    @catinfo    = session[:cloud_volume_catinfo]
    @showtype   = session[:cloud_volume_showtype]
  end

  def set_session_data
    session[:cloud_volume_lastaction] = @lastaction
    session[:cloud_volume_display]    = @display unless @display.nil?
    session[:cloud_volume_filters]    = @filters
    session[:cloud_volume_catinfo]    = @catinfo
    session[:cloud_volume_showtype]   = @showtype
  end
end
