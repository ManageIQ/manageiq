class CloudObjectStoreContainerController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin

  def breadcrumb_name(_model)
    ui_lookup(:tables => "cloud_object_store_container")
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh
    return tag("CloudObjectStoreContainer") if params[:pressed] == 'cloud_object_store_container_tag'
  end

  def show
    @display = params[:display] || "main" unless control_selected?
    @showtype = @display
    @lastaction = "show"

    @cloud_object_store_container = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@record)

    @gtl_url = "/show"
    drop_breadcrumb(
      {
        :name => ui_lookup(:tables => "cloud_object_stores"),
        :url  => "/cloud_object_store_container/show_list?page=#{@current_page}&refresh=y"
      },
      true
    )

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@record)
      drop_breadcrumb(
        :name => _("%{name} (Summary)") % {:name => @record.key.to_s},
        :url  => "/cloud_object_store_container/show/#{@record.id}"
      )
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    when "cloud_object_store_objects"
      title = ui_lookup(:tables => 'cloud_objects')
      kls   = CloudObjectStoreObject
      drop_breadcrumb(
        :name => _("%{name} (All %{title})") % {:name => @record.name, :title => title},
        :url  => "/cloud_object_store_container/show/#{@record.id}?display=cloud_object_store_objects"
      )
      @view, @pages = get_view(kls, :parent => @record, :association => :cloud_object_store_objects)
      @showtype = "cloud_object_store_objects"
    end

    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  private

  def get_session_data
    @title      = _("Cloud Object Stores")
    @layout     = "cloud_object_store_container"
    @lastaction = session[:cloud_object_store_container_lastaction]
    @display    = session[:cloud_object_store_container_display]
    @filters    = session[:cloud_object_store_container_filters]
    @catinfo    = session[:cloud_object_store_container_catinfo]
    @showtype   = session[:cloud_object_store_container_showtype]
  end

  def set_session_data
    session[:cloud_object_store_container_lastaction] = @lastaction
    session[:cloud_object_store_container_display]    = @display unless @display.nil?
    session[:cloud_object_store_container_filters]    = @filters
    session[:cloud_object_store_container_catinfo]    = @catinfo
    session[:cloud_object_store_container_showtype]   = @showtype
  end

  menu_section :sto
end
