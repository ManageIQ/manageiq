class AuthKeyPairCloudController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def breadcrumb_name(_model)
    ui_lookup(:tables => "auth_key_pair_cloud")
  end

  def self.table_name
    @table_name ||= "auth_key_pair_cloud"
  end

  def self.model
    ManageIQ::Providers::CloudManager::AuthKeyPair
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh
    return tag("ManageIQ::Providers::CloudManager::AuthKeyPair") if params[:pressed] == 'auth_key_pair_cloud_tag'
    if @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render_flash
    end
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype = "main"
    @auth_key_pair_cloud = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@auth_key_pair_cloud)

    @gtl_url = "/auth_key_pair_cloud/show/#{@auth_key_pair_cloud.id}?"
    drop_breadcrumb(
      {:name => _("Key Pairs"), :url => "/auth_key_pair_cloud/show_list?page=#{@current_page}&refresh=y"},
      true
    )

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@auth_key_pair_cloud)
      drop_breadcrumb(
        :name => @auth_key_pair_cloud.name + " (Summary)",
        :url  => "/auth_key_pair_cloud/show/#{@auth_key_pair_cloud.id}"
      )
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    when "instances"
      title = ui_lookup(:tables => 'vm_cloud')
      kls   = ManageIQ::Providers::CloudManager::Vm
      drop_breadcrumb(
        :name => _(":{name} (All %{title})") % {:name => @auth_key_pair_cloud.name, :title => title},
        :url  => "/auth_key_pair_cloud/show/#{@auth_key_pair_cloud.id}?display=instances"
      )
      @view, @pages = get_view(kls, :parent => @auth_key_pair_cloud) # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
         @view.extras[:total_count] > @view.extras[:auth_count]
        count = @view.extras[:total_count] - @view.extras[:auth_count]
        @bottom_msg = _("* You are not authorized to view %{children} on this %{model}") % {
          :children => pluralize(count, "other #{title.singularize}"),
          :model    => ui_lookup(:tables => "auth_key_pair_cloud")
        }
      end
    end

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def show_list
    process_show_list
  end

  private

  def get_session_data
    @title      = _("Key Pair")
    @layout     = "auth_key_pair_cloud"
    @lastaction = session[:auth_key_pair_cloud_lastaction]
    @display    = session[:auth_key_pair_cloud_display]
    @filters    = session[:auth_key_pair_cloud_filters]
    @catinfo    = session[:auth_key_pair_cloud_catinfo]
  end

  def set_session_data
    session[:auth_key_pair_cloud_lastaction] = @lastaction
    session[:auth_key_pair_cloud_display]    = @display unless @display.nil?
    session[:auth_key_pair_cloud_filters]    = @filters
    session[:auth_key_pair_cloud_catinfo]    = @catinfo
  end
end
