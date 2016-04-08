class AuthKeyPairCloudController < ApplicationController
  include AuthorizationMessagesMixin
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
    delete_auth_key_pairs if params[:pressed] == 'auth_key_pair_cloud_delete'
    new if params[:pressed] == 'auth_key_pair_cloud_new'

    if !@flash_array.nil? && params[:pressed] == "auth_key_pair_cloud_delete" && @single_delete
      render :update do |page|
        page << javascript_prologue
        # redirect to build the retire screen
        page.redirect_to :action => 'show_list', :flash_msg => @flash_array[0][:message]
      end
    elsif params[:pressed] == "auth_key_pair_cloud_new"
      if @flash_array
        show_list
        replace_gtl_main_div
      else
        render :update do |page|
          page << javascript_prologue
          page.redirect_to :action => "new"
        end
      end
    elsif @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render_flash
    end
  end

  def get_form_vars
    if !@edit[:auth_key_pair_cloud_id].nil?
      @key_pair = ManageIQ::Providers::CloudManager::AuthKeyPair.find_by_id(@edit[:auth_key_pair_cloud_id])
    else
      @key_pair = ManageIQ::Providers::CloudManager::AuthKeyPair.new
    end
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:public_key] = params[:public_key] if params[:public_key]
    @edit[:new][:ems_id] = params[:ems_id] if params[:ems_id]
  end

  def set_form_vars
    @edit = {}
    @edit[:auth_key_pair_cloud_id] = @key_pair.id
    @edit[:key] = "auth_key_pair_cloud_edit__#{@key_pair.id || "new"}"
    @edit[:new] = {}

    @edit[:ems_choices] = {}
    ManageIQ::Providers::CloudManager.all.each { |ems| @edit[:ems_choices][ems.name] = ems.id }
    @edit[:new][:ems_id] = @edit[:ems_choices].values[0] unless @edit[:ems_choices].empty?

    @edit[:new][:name] = @key_pair.name
    @edit[:current] = @edit[:new].dup
    session[:edit] = @edit
  end

  def form_field_changed
    return unless load_edit("auth_key_pair_cloud_edit__#{params[:id] || 'new'}")
    get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      page.replace(@refresh_div, :partial => @refresh_partial) if @refresh_div
      page << javascript_for_miq_button_visibility(true)
    end
  end

  def new
    assert_privileges("auth_key_pair_cloud_new")
    @key_pair = ManageIQ::Providers::CloudManager::AuthKeyPair.new
    set_form_vars
    @in_a_form = true
    session[:changed] = nil
    drop_breadcrumb(
      :name => _("Add New %{model}") % {:model => ui_lookup(:table => 'auth_key_pair_cloud')},
      :url  => "/auth_key_pair_cloud/new"
    )
  end

  def create
    assert_privileges("auth_key_pair_cloud_new")
    kls = ManageIQ::Providers::CloudManager::AuthKeyPair
    case params[:button]
    when "cancel"
      render :update do |page|
        page << javascript_prologue
        page.redirect_to :action    => 'show_list',
                         :flash_msg => _("Add of new %{model} was cancelled by the user") % {
                           :model => ui_lookup(:table => 'auth_key_pair_cloud')
                         }
      end

    when "add"
      return unless load_edit("auth_key_pair_cloud_edit__new")
      get_form_vars

      options = @edit[:new]
      ext_management_system = find_by_id_filtered(ManageIQ::Providers::CloudManager, options[:ems_id])
      valid_action, action_details = kls.validate_create_key_pair(ext_management_system, options)
      if valid_action
        begin
          kls.create_key_pair(ext_management_system, options)
          add_flash(_("Creating %{model} %{name}") % {
            :model => ui_lookup(:table => 'auth_key_pair_cloud'),
            :name  => options[:name]})
        rescue => ex
          add_flash(_("Unable to create %{model} %{name} %{error}") % {
            :model => ui_lookup(:table => 'auth_key_pair_cloud'),
            :name  => options[:name],
            :error => ex}, :error)
        end
        @breadcrumbs.pop if @breadcrumbs
        session[:edit] = nil
        session[:flash_msgs] = @flash_array.dup if @flash_array
        render :update do |page|
          page << javascript_prologue
          page.redirect_to :action => "show_list"
        end
      else
        @in_a_form = true
        add_flash(_(action_details), :error) unless action_details.nil?
        drop_breadcrumb(
          :name => _("Add New %{model}") % {:model => ui_lookup(:table => 'auth_key_pair_cloud')},
          :url  => "/auth_key_pair_cloud/new"
        )
        render :update do |page|
          page << javascript_prologue
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end

    when "validate"
      @in_a_form = true
      options = @edit[:new]
      ext_management_system = find_by_id_filtered(options[:ems_id])
      valid_action, action_details = kls.validate_create_key_pair(ext_management_system, options)
      if valid_action
        add_flash(_("Validation successful"))
      else
        add_flash(_(action_details), :error) unless details.nil?
      end
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    end
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype = "main"
    @auth_key_pair_cloud = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@auth_key_pair_cloud)

    @gtl_url = "/show"
    drop_breadcrumb(
      {:name => _("Key Pairs"), :url => "/auth_key_pair_cloud/show_list?page=#{@current_page}&refresh=y"},
      true
    )

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@auth_key_pair_cloud)
      drop_breadcrumb(
        :name => _("%{name} (Summary)") % {:name => @auth_key_pair_cloud.name},
        :url  => "/auth_key_pair_cloud/show/#{@auth_key_pair_cloud.id}"
      )
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    when "instances"
      title = ui_lookup(:tables => 'vm_cloud')
      kls   = ManageIQ::Providers::CloudManager::Vm
      drop_breadcrumb(
        :name => _("%{name} (All %{title})") % {:name => @auth_key_pair_cloud.name, :title => title},
        :url  => "/auth_key_pair_cloud/show/#{@auth_key_pair_cloud.id}?display=instances"
      )
      @view, @pages = get_view(kls, :parent => @auth_key_pair_cloud) # Get the records (into a view) and the paginator
      @showtype = @display
      notify_about_unauthorized_items(title, ui_lookup(:tables => "auth_key_pair_cloud"))
    end

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def show_list
    process_show_list
  end

  # delete selected auth key pairs
  def delete_auth_key_pairs
    assert_privileges("auth_key_pair_cloud_delete")
    key_pairs = []

    if @lastaction == "show_list" || (@lastaction == "show" && @layout != "auth_key_pair_cloud")
      key_pairs = find_checked_items
    else
      key_pairs = [params[:id]]
    end

    if key_pairs.empty?
      add_flash(_("No #{ui_lookup(:tables => 'auth_key_pair_cloud')} were selected for deletion"), :error)
    end

    key_pairs_to_delete = []
    key_pairs.each do |k|
      key_pair = ManageIQ::Providers::CloudManager::AuthKeyPair.find_by_id(k)
      if key_pair.nil?
        add_flash(_("%{model} no longer exists.") % {:model => ui_lookup(:table => "auth_key_pair_cloud")}, :error)
      else
        valid_delete, delete_details = key_pair.validate_delete_key_pair
        if valid_delete
          key_pairs_to_delete.push(k)
        else
          add_flash(_("Couldn't initiate deletion of %{model} \"%{name}\": %{details}") % {
            :model   => ui_lookup(:table => 'auth_key_pair_cloud'),
            :name    => key_pair.name,
            :details => delete_details
          }, :error)
        end
      end
    end
    process_deletions(key_pairs_to_delete) unless key_pairs_to_delete.empty?

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "auth_key_pair_cloud"
      @single_delete = true unless flash_errors?
      add_flash(_("The selected %{model} was deleted") % {
        :model => ui_lookup(:table => "auth_key_pair_cloud")
      }) if @flash_array.nil?
    end
  end

  def process_deletions(key_pairs)
    return if key_pairs.empty?

    ManageIQ::Providers::CloudManager::AuthKeyPair.where(:id => key_pairs).order('lower(name)').each do |kp|
      audit = {
        :event        => "auth_key_pair_cloud_record_delete_initiateed",
        :message      => "[#{kp.name}] Record delete initiated",
        :target_id    => kp.id,
        :target_class => "ManageIQ::Providers::CloudManager::AuthKeyPair",
        :userid       => session[:userid]
      }
      AuditEvent.success(audit)
      kp.delete_key_pair
      kp.destroy
    end
    add_flash(_("Delete initiated for %{models}") % {
      :models => pluralize(key_pairs.length, ui_lookup(:table => 'auth_key_pair_cloud'))
    })
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
