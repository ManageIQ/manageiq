class AuthKeyPairCloudController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericShowMixin
  include Mixins::GenericListMixin
  include Mixins::GenericSessionMixin

  def self.display_methods
    %w(instances)
  end

  def show_list
    process_show_list(:dbname => :authkeypaircloud)
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
      javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message] # redirect to build the retire screen
    elsif params[:pressed] == "auth_key_pair_cloud_new"
      if @flash_array
        show_list
        replace_gtl_main_div
      else
        javascript_redirect :action => "new"
      end
    elsif @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render_flash
    end
  end

  def set_form_vars
    @edit = {}
    @edit[:auth_key_pair_cloud_id] = @key_pair.id
    @edit[:key] = "auth_key_pair_cloud_edit__#{@key_pair.id || "new"}"
    @edit[:new] = {}

    @edit[:ems_choices] = {}
    ManageIQ::Providers::CloudManager.all.each do |ems|
      @edit[:ems_choices][ems.name] = ems.id if ems.class::AuthKeyPair.is_available?(:create_key_pair, ems)
    end
    @edit[:new][:ems_id] = @edit[:ems_choices].values[0] unless @edit[:ems_choices].empty?

    @edit[:new][:name] = @key_pair.name
    @edit[:current] = @edit[:new].dup
    session[:edit] = @edit
  end

  # REST call for provider choices
  def ems_form_choices
    assert_privileges("auth_key_pair_cloud_new")
    ems_choices = ManageIQ::Providers::CloudManager.select do |ems|
      ems.class::AuthKeyPair.is_available?(:create_key_pair, ems)
    end
    ems_choices.each do |ems|
      {:name => ems.name, :id => ems.id}
    end
    render :json => {:ems_choices => ems_choices}
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
    options = {
      :name       => params[:name],
      :public_key => params[:public_key],
      :ems_id     => params[:ems_id]
    }

    case params[:button]
    when "cancel"
      javascript_redirect :action    => 'show_list',
                          :flash_msg => _("Add of new %{model} was cancelled by the user") %
                          {:model => ui_lookup(:table => 'auth_key_pair_cloud')}
    when "save"
      ext_management_system = find_by_id_filtered(ManageIQ::Providers::CloudManager, options[:ems_id])
      kls = kls.class_by_ems(ext_management_system)
      if kls.is_available?(:create_key_pair, ext_management_system, options)
        begin
          kls.create_key_pair(ext_management_system, options)
          add_flash(_("Creating %{model} %{name}") % {
            :model => ui_lookup(:table => 'auth_key_pair_cloud'),
            :name  => options[:name]})
        rescue => ex
          add_flash(_("Unable to create %{model} %{name}. %{error}") % {
            :model => ui_lookup(:table => 'auth_key_pair_cloud'),
            :name  => options[:name],
            :error => get_error_message_from_fog(ex.to_s)}, :error)
        end
        @breadcrumbs.pop if @breadcrumbs
        session[:edit] = nil
        session[:flash_msgs] = @flash_array.dup if @flash_array
        javascript_redirect :action => "show_list"
      else
        @in_a_form = true
        add_flash(kls.is_available_now_error_message(:create_key_pair, ext_management_system, kls))
        drop_breadcrumb(
          :name => _("Add New %{model}") % {:model => ui_lookup(:table => 'auth_key_pair_cloud')},
          :url  => "/auth_key_pair_cloud/new"
        )
        javascript_flash
      end
    when "validate"
      @in_a_form = true
      ext_management_system = find_by_id_filtered(ManageIQ::Providers::CloudManager, options[:ems_id])
      kls = kls.class_by_ems(ext_management_system)
      if kls.is_available?(:create_key_pair, ext_management_system, options)
        add_flash(_("Validation successful"))
      else
        add_flash(kls.is_available_now_error_message(:create_key_pair, ext_management_system, options))
      end
      javascript_flash
    end
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
      add_flash(_("No %#{models} were selected for deletion") % {:models =>  ui_lookup(:tables => 'auth_key_pair_cloud')}, :error)
    end

    key_pairs_to_delete = []
    key_pairs.each do |k|
      key_pair = ManageIQ::Providers::CloudManager::AuthKeyPair.find_by_id(k)
      if key_pair.nil?
        add_flash(_("%{model} no longer exists.") % {:model => ui_lookup(:table => "auth_key_pair_cloud")}, :error)
      else
        if key_pair.is_available?(:delete_key_pair)
          key_pairs_to_delete.push(k)
        else
          add_flash(_("Couldn't initiate deletion of %{model} \"%{name}\": %{details}") % {
            :model   => ui_lookup(:table => 'auth_key_pair_cloud'),
            :name    => key_pair.name,
            :details => key_pair.is_available_now_error_message(:delete_key_pair)
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
    add_flash(n_("Delete initiated for %{number} Key Pair",
                 "Delete initiated for %{number} Key Pairs", key_pairs.length) % {:number => key_pairs.length})
  end

  menu_section :clo
end
