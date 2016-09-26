module OpsController::Settings::Common
  extend ActiveSupport::Concern

  logo_dir = File.expand_path(File.join(Rails.root, "public/upload"))
  Dir.mkdir logo_dir unless File.exist?(logo_dir)
  @@logo_file = File.join(logo_dir, "custom_logo.png")
  @@login_logo_file = File.join(logo_dir, "custom_login_logo.png")

  # AJAX driven routine to check for changes in ANY field on the form
  def settings_form_field_changed
    tab = params[:id] ? "settings_#{params[:id]}" : nil # workaround to prevent an error that happens when IE sends a transaction when tab is changed when there is text_area in the form, checking for tab id
    if tab && tab != @sb[:active_tab] && params[:id] != 'new'
      head :ok
      return
    end

    settings_get_form_vars
    return unless @edit
    @assigned_filters = []
    case @sb[:active_tab] # Server, DB edit forms
    when 'settings_server', 'settings_authentication',
         'settings_custom_logos'
      @changed = (@edit[:new] != @edit[:current].config)
      if params[:console_type]
        @refresh_div     = 'settings_server'              # Replace main area
        @refresh_partial = 'settings_server_tab'
      end
    when 'settings_rhn_edit'
      if params[:use_proxy] || params[:register_to] || ['rhn_default_server', 'repo_default_name'].include?(params[:action])
        @refresh_div     = 'settings_rhn'
        @refresh_partial = 'settings_rhn_edit_tab'
      else
        @refresh_div = nil
      end
    when 'settings_workers'
      @changed = (@edit[:new].config != @edit[:current].config)
      if @edit[:new].config[:workers][:worker_base][:ui_worker][:count] != @edit[:current].config[:workers][:worker_base][:ui_worker][:count]
        add_flash(_("Changing the UI Workers Count will immediately restart the webserver"), :warning)
      end
    when 'settings_advanced'                                # Advanced yaml edit
      @changed = (@edit[:new] != @edit[:current])
    end

    render :update do |page|
      page << javascript_prologue
      page.replace_html(@refresh_div, :partial => @refresh_partial) if @refresh_div

      case @sb[:active_tab]
      when 'settings_server'
        if @test_email_button
          page << javascript_hide("email_verify_button_off")
          page << javascript_show("email_verify_button_on")
        else
          page << javascript_hide("email_verify_button_on")
          page << javascript_show("email_verify_button_off")
        end

        if @smtp_auth_none
          page << javascript_disable_field('smtp_user_name')
          page << javascript_disable_field('smtp_password')
        else
          page << javascript_enable_field('smtp_user_name')
          page << javascript_enable_field('smtp_password')
        end

        if @changed || @login_text_changed
          page << javascript_hide_if_exists("server_options_on")
          page << javascript_show_if_exists("server_options_off")
        else
          page << javascript_hide_if_exists("server_options_off")
          page << javascript_show_if_exists("server_options_on")
        end
      when 'settings_authentication'
        if @authmode_changed
          if ["ldap", "ldaps"].include?(@edit[:new][:authentication][:mode])
            page << javascript_show("ldap_div")
            page << javascript_show("ldap_role_div")
            page << javascript_show("ldap_role_div")

            page << set_element_visible("user_proxies_div",        @edit[:new][:authentication][:ldap_role])
            page << set_element_visible("ldap_role_details_div",   @edit[:new][:authentication][:ldap_role])
            page << set_element_visible("ldap_default_group_div", !@edit[:new][:authentication][:ldap_role])

            page << (@edit[:new][:authentication][:ldap_role] ? javascript_checked('ldap_role') : javascript_unchecked('ldap_role'))
          else
            page << javascript_hide("ldap_div")
            page << javascript_hide("ldap_role_div")
            page << javascript_hide("user_proxies_div")
          end
          verb = @edit[:new][:authentication][:mode] == 'amazon'
          page << set_element_visible("amazon_div", verb)
          page << set_element_visible("amazon_role_div", verb)

          verb = @edit[:new][:authentication][:mode] == 'httpd'
          page << set_element_visible("httpd_div", verb)
          page << set_element_visible("httpd_role_div", verb)
        end
        if @authusertype_changed
          verb = @edit[:new][:authentication][:user_type] == 'samaccountname'
          page << set_element_visible("user_type_samaccountname", verb)
          page << set_element_visible("user_type_base", !verb)
          if @edit[:new][:authentication][:user_type] == "dn-cn"
            page << javascript_hide("upn-mail_prefix")
            page << javascript_hide("dn-uid_prefix")
            page << javascript_show("dn-cn_prefix")
          elsif @edit[:new][:authentication][:user_type] == "dn-uid"
            page << javascript_hide("upn-mail_prefix")
            page << javascript_hide("dn-cn_prefix")
            page << javascript_show("dn-uid_prefix")
          else
            page << javascript_hide("dn-cn_prefix")
            page << javascript_hide("dn-uid_prefix")
            page << javascript_show("upn-mail_prefix")
          end
        end
        if @authldaprole_changed
          page << set_element_visible("user_proxies_div", @edit[:new][:authentication][:ldap_role])
          page << set_element_visible("ldap_role_details_div", @edit[:new][:authentication][:ldap_role])
          page << set_element_visible("ldap_default_group_div", !@edit[:new][:authentication][:ldap_role])
        end
        if @authldapport_reset
          page << "$('#authentication_ldapport').val('#{@edit[:new][:authentication][:ldapport]}');"
        end
        if @reset_verify_button
          if !@edit[:new][:authentication][:ldaphost].empty? && !@edit[:new][:authentication][:ldapport].nil?
            page << javascript_hide("verify_button_off")
            page << javascript_show("verify_button_on")
          else
            page << javascript_hide("verify_button_on")
            page << javascript_show("verify_button_off")
          end
        end
        if @reset_amazon_verify_button
          if !@edit[:new][:authentication][:amazon_key].nil? && !@edit[:new][:authentication][:amazon_secret].nil?
            page << javascript_hide("amazon_verify_button_off")
            page << javascript_show("amazon_verify_button_on")
          else
            page << javascript_hide("amazon_verify_button_on")
            page << javascript_show("amazon_verify_button_off")
          end
        end
      when 'settings_workers'
        if @edit[:default_verify_status] != session[:log_depot_default_verify_status]
          session[:log_depot_default_verify_status] = @edit[:default_verify_status]
          verb = @edit[:default_verify_status] ? 'show' : 'hide'
          page << "miqValidateButtons('#{verb}', 'default_');"
        end
        if @edit[:new].config[:workers][:worker_base][:ui_worker][:count] != @edit[:current].config[:workers][:worker_base][:ui_worker][:count]
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        page.replace_html('pwd_note', @edit[:default_verify_status] ? '' : _("* Passwords don't match."))
      end

      page << javascript_for_miq_button_visibility(@changed || @login_text_changed)
    end
  end

  def settings_update
    case params[:button]
    when 'verify'        then settings_update_ldap_verify
    when 'amazon_verify' then settings_update_amazon_verify
    when 'email_verify'  then settings_update_email_verify
    when 'save'          then settings_update_save
    when 'reset'         then settings_update_reset
    when 'cancel'        then settings_update_cancel
    end
  end

  def smartproxy_affinity_field_changed
    settings_load_edit
    return unless @edit

    smartproxy_affinity_get_form_vars(params[:id], params[:check] == '1') if params[:id] && params[:check]

    javascript_miq_button_visibility(@edit[:new] != @edit[:current])
  end

  def pglogical_subscriptions_form_fields
    replication_type = MiqRegion.replication_type
    subscriptions = replication_type == :global ? PglogicalSubscription.all : []
    subscriptions = get_subscriptions_array(subscriptions) unless subscriptions.empty?
    render :json => {
      :replication_type => replication_type,
      :subscriptions    => subscriptions
    }
  end

  def pglogical_save_subscriptions
    replication_type = valid_replication_type
    if replication_type == :global
      MiqRegion.replication_type = replication_type
      subscriptions_to_save = []
      params[:subscriptions].each do |_, subscription_params|
        subscription = find_or_new_subscription(subscription_params['id'])
        if subscription.id && subscription_params['remove'] == "true"
          subscription.delete
        else
          set_subscription_attributes(subscription, subscription_params)
          subscriptions_to_save.push(subscription)
        end
      end
      begin
        PglogicalSubscription.save_all!(subscriptions_to_save)
      rescue  StandardError => bang
        add_flash(_("Error during replication configuration save: %{message}") %
                    {:message => bang}, :error)
      else
        add_flash(_("Replication configuration save was successful"))
      end
    else
      begin
        MiqRegion.replication_type = replication_type
      rescue StandardError => bang
        add_flash(_("Error during replication configuration save: %{message}") %
                    {:message => bang.message}, :error)
      else
        add_flash(_("Replication configuration save was successful"))
      end
    end
    javascript_flash(:spinner_off => true)
  end

  def pglogical_validate_subscription
    subscription = find_or_new_subscription(params[:id])
    valid = subscription.validate(params_for_connection_validation(params))
    if valid.nil?
      add_flash(_("Subscription Credentials validated successfully"))
    else
      valid.each do |v|
        add_flash(v, :error)
      end
    end
    javascript_flash
  end

  private

  PASSWORD_MASK = '●●●●●●●●'.freeze

  def find_or_new_subscription(id = nil)
    id.nil? ? PglogicalSubscription.new : PglogicalSubscription.find(id)
  end

  def set_subscription_attributes(subscription, params)
    params_for_connection_validation(params).each do |k, v|
      subscription.send("#{k}=".to_sym, v)
    end
  end

  def params_for_connection_validation(subscription_params)
    {'host'     => subscription_params['host'],
     'port'     => subscription_params['port'],
     'user'     => subscription_params['user'],
     'dbname'   => subscription_params['dbname'],
     'password' => subscription_params['password'] == PASSWORD_MASK ? nil : subscription_params['password']
    }.delete_blanks
  end

  def get_subscriptions_array(subscriptions)
    subscriptions.collect { |sub|
      {:dbname => sub.dbname,
       :host     => sub.host,
       :id       => sub.id,
       :user     => sub.user,
       :password => '●●●●●●●●',
       :port     => sub.port
      }
    }
  end

  def valid_replication_type
    return params[:replication_type].to_sym if %w(global none remote).include?(params[:replication_type])
  end

  def settings_update_ldap_verify
    settings_get_form_vars
    return unless @edit
    server_config = MiqServer.find(@sb[:selected_server_id]).get_config("vmdb")
    server_config.config.each_key do |category|
      server_config.config[category] = @edit[:new][category].dup
    end

    valid, errors = MiqLdap.validate_connection(server_config.config)
    if valid
      add_flash(_("LDAP Settings validation was successful"))
    else
      errors.each do |field, msg|
        add_flash("#{field.titleize}: #{msg}", :error)
      end
    end

    javascript_flash
  end

  def settings_update_amazon_verify
    settings_get_form_vars
    return unless @edit
    server_config = MiqServer.find(@sb[:selected_server_id]).get_config("vmdb")
    server_config.config.each_key do |category|
      server_config.config[category] = @edit[:new][category].dup
    end

    valid, errors = Authenticator::Amazon.validate_connection(server_config.config)
    if valid
      add_flash(_("Amazon Settings validation was successful"))
    else
      errors.each do |field, msg|
        add_flash("#{field.titleize}: #{msg}", :error)
      end
    end
    javascript_flash
  end

  def settings_update_email_verify
    settings_get_form_vars
    return unless @edit
    begin
      GenericMailer.test_email(@sb[:new_to], @edit[:new][:smtp]).deliver
    rescue Exception => err
      add_flash(_("Error during sending test email: %{class_name}, %{error_message}") %
        {:class_name => err.class.name, :error_message => err.to_s}, :error)
    else
      add_flash(_("The test email is being delivered, check \"%{email}\" to verify it was successful") %
                  {:email => @sb[:new_to]})
    end
    javascript_flash
  end

  def settings_update_save
    settings_get_form_vars
    return unless @edit
    case @sb[:active_tab]
    when 'settings_rhn_edit'
      if rhn_allow_save?
        rhn_save_subscription
      else
        render_flash
      end
      return
    when "settings_smartproxy_affinity"
      smartproxy_affinity_update
    when "settings_server", "settings_authentication"
      # Server Settings
      settings_server_validate
      unless @flash_array.blank?
        render_flash
        return
      end
      @edit[:new][:authentication][:ldaphost].reject!(&:blank?) if @edit[:new][:authentication][:ldaphost]
      @changed = (@edit[:new] != @edit[:current].config)
      server = MiqServer.find(@sb[:selected_server_id])
      zone = Zone.find_by_name(@edit[:new][:server][:zone])
      unless zone.nil? || server.zone == zone
        server.zone = zone
        server.save
      end
      @update = server.get_config("vmdb")
    when "settings_workers"                                   # Workers Settings
      @changed = (@edit[:new] != @edit[:current].config)
      qwb = @edit[:new].config[:workers][:worker_base][:queue_worker_base]
      w = qwb[:generic_worker]
      @edit[:new].set_worker_setting!(:MiqGenericWorker, :count, w[:count].to_i)
      @edit[:new].set_worker_setting!(:MiqGenericWorker, :memory_threshold, human_size_to_rails_method(w[:memory_threshold]))

      w = qwb[:priority_worker]
      @edit[:new].set_worker_setting!(:MiqPriorityWorker, :count, w[:count].to_i)
      @edit[:new].set_worker_setting!(:MiqPriorityWorker, :memory_threshold, human_size_to_rails_method(w[:memory_threshold]))

      w = qwb[:ems_metrics_collector_worker][:defaults]
      @edit[:new].set_worker_setting!(:MiqEmsMetricsCollectorWorker, [:defaults, :count], w[:count].to_i)
      @edit[:new].set_worker_setting!(:MiqEmsMetricsCollectorWorker, [:defaults, :memory_threshold], human_size_to_rails_method(w[:memory_threshold]))

      w = qwb[:ems_metrics_processor_worker]
      @edit[:new].set_worker_setting!(:MiqEmsMetricsProcessorWorker, :count, w[:count].to_i)
      @edit[:new].set_worker_setting!(:MiqEmsMetricsProcessorWorker, :memory_threshold, human_size_to_rails_method(w[:memory_threshold]))

      w = qwb[:ems_refresh_worker][:defaults]
      @edit[:new].set_worker_setting!(:MiqEmsRefreshWorker, [:defaults, :memory_threshold], human_size_to_rails_method(w[:memory_threshold]))

      wb = @edit[:new].config[:workers][:worker_base]
      w = wb[:event_catcher]
      @edit[:new].set_worker_setting!(:MiqEventCatcher, :memory_threshold, human_size_to_rails_method(w[:memory_threshold]))

      w = wb[:vim_broker_worker]
      @edit[:new].set_worker_setting!(:MiqVimBrokerWorker, :memory_threshold, human_size_to_rails_method(w[:memory_threshold]))

      w = qwb[:smart_proxy_worker]
      @edit[:new].set_worker_setting!(:MiqSmartProxyWorker, :count, w[:count].to_i)
      @edit[:new].set_worker_setting!(:MiqSmartProxyWorker, :memory_threshold, human_size_to_rails_method(w[:memory_threshold]))

      w = wb[:ui_worker]
      @edit[:new].set_worker_setting!(:MiqUiWorker, :count, w[:count].to_i)

      w = qwb[:reporting_worker]
      @edit[:new].set_worker_setting!(:MiqReportingWorker, :count, w[:count].to_i)
      @edit[:new].set_worker_setting!(:MiqReportingWorker, :memory_threshold, human_size_to_rails_method(w[:memory_threshold]))

      w = wb[:web_service_worker]
      @edit[:new].set_worker_setting!(:MiqWebServiceWorker, :count, w[:count].to_i)
      @edit[:new].set_worker_setting!(:MiqWebServiceWorker, :memory_threshold, human_size_to_rails_method(w[:memory_threshold]))

      w = wb[:websocket_worker]
      @edit[:new].set_worker_setting!(:MiqWebsocketWorker, :count, w[:count].to_i)

      @update = MiqServer.find(@sb[:selected_server_id]).get_config
    when "settings_custom_logos"                                      # Custom Logo tab
      @changed = (@edit[:new] != @edit[:current].config)
      @update = VMDB::Config.new("vmdb")                    # Get the settings object to update it
    when "settings_advanced"                                          # Advanced manual yaml editor tab
      result = VMDB::Config.save_file(@edit[:new][:file_data])  # Save the config file
      if result != true                                         # Result contains errors?
        result.each do |field, msg|
          add_flash("#{field.to_s.titleize}: #{msg}", :error)
        end
        @changed = (@edit[:new] != @edit[:current])
      else
        add_flash(_("Configuration changes saved"))
        @changed = false
      end
      #     redirect_to :action => 'explorer', :flash_msg=>msg, :flash_error=>err, :no_refresh=>true
      get_node_info(x_node)
      replace_right_cell(@nodetype)
      return
    end
    if !%w(settings_advanced settings_rhn_edit settings_workers).include?(@sb[:active_tab]) &&
       x_node.split("-").first != "z"
      @update.config.each_key do |category|
        @update.config[category] = @edit[:new][category].dup
      end
      @update.config[:ntp] = @edit[:new][:ntp].dup if @edit[:new][:ntp]
      @update.config[:ntp][:server].reject!(&:blank?) if @update.config[:ntp]
      if @update.validate                                           # Have VMDB class validate the settings
        if ["settings_server", "settings_authentication"].include?(@sb[:active_tab])
          server = MiqServer.find(@sb[:selected_server_id])
          server.set_config(@update)
          if @update.config[:server][:name] != server.name # appliance name was modified
            begin
              server.name = @update.config[:server][:name]
              server.save!
            rescue StandardError => bang
              add_flash(_("Error when saving new server name: %{message}") % {:message => bang.message}, :error)
              javascript_flash
              return
            end
          end
        else
          @update.save                                              # Save other settings for current server
        end
        AuditEvent.success(build_config_audit(@edit[:new], @edit[:current].config))
        if @sb[:active_tab] == "settings_server"
          add_flash(_("Configuration settings saved for ManageIQ Server \"%{name} [%{server_id}]\" in Zone \"%{zone}\"") %
                      {:name => server.name, :server_id => server.id, :zone => server.my_zone})
        elsif @sb[:active_tab] == "settings_authentication"
          add_flash(_("Authentication settings saved for ManageIQ Server \"%{name} [%{server_id}]\" in Zone \"%{zone}\"") %
                      {:name => server.name, :server_id => server.id, :zone => server.my_zone})
        else
          add_flash(_("Configuration settings saved"))
        end
        if @sb[:active_tab] == "settings_server" && @sb[:selected_server_id] == MiqServer.my_server.id  # Reset session variables for names fields, if editing current server config
          session[:customer_name] = @update.config[:server][:company]
          session[:vmdb_name] = @update.config[:server][:name]
        end
        set_user_time_zone if @sb[:active_tab] == "settings_server"
        # settings_set_form_vars
        session[:changed] = @changed = false
        get_node_info(x_node)
        if @sb[:active_tab] == "settings_server"
          replace_right_cell(@nodetype, [:diagnostics, :settings])
        elsif @sb[:active_tab] == "settings_custom_logos"
          javascript_redirect :action => 'explorer', :flash_msg => @flash_array[0][:message], :flash_error => @flash_array[0][:level] == :error, :escape => false # redirect to build the server screen
          return
        else
          replace_right_cell(@nodetype)
        end
      else
        @update.errors.each do |field, msg|
          add_flash("#{field.titleize}: #{msg}", :error)
        end
        @changed = true
        session[:changed] = @changed
        get_node_info(x_node)
        replace_right_cell(@nodetype)
      end
    elsif @sb[:active_tab] == "settings_workers" &&
          x_node.split("-").first != "z"
      unless @edit[:default_verify_status]
        add_flash(_("Password/Verify Password do not match"), :error)
      end
      unless @flash_array.nil?
        session[:changed] = @changed = true
        javascript_flash
        return
      end
      @update.config.each_key do |category|
        @update.config[category] = @edit[:new].config[category].dup
      end
      if @update.validate                                           # Have VMDB class validate the settings
        server = MiqServer.find(@sb[:selected_server_id])
        server.set_config(@update)

        AuditEvent.success(build_config_audit(@edit[:new].config, @edit[:current].config))
        add_flash(_("Configuration settings saved for ManageIQ Server \"%{name} [%{server_id}]\" in Zone \"%{zone}\"") %
                    {:name => server.name, :server_id => @sb[:selected_server_id], :zone => server.my_zone})

        if @sb[:active_tab] == "settings_workers" && @sb[:selected_server_id] == MiqServer.my_server.id  # Reset session variables for names fields, if editing current server config
          session[:customer_name] = @update.config[:server][:company]
          session[:vmdb_name] = @update.config[:server][:name]
        end
        @changed = false
        get_node_info(x_node)
        replace_right_cell(@nodetype)
      else
        @update.errors.each do |field, msg|
          add_flash("#{field.titleize}: #{msg}", :error)
        end
        @changed = true
        get_node_info(x_node)
        replace_right_cell(@nodetype)
      end
    else
      @changed = false
      get_node_info(x_node)
      replace_right_cell(@nodetype)
    end
  end

  def settings_update_reset
    session[:changed] = @changed = false
    add_flash(_("All changes have been reset"), :warning)
    if @sb[:active_tab] == 'settings_rhn_edit'
      edit_rhn
    else
      get_node_info(x_node)
      replace_right_cell(@nodetype)
    end
  end

  def settings_update_cancel
    @sb[:active_tab] = 'settings_rhn'
    @changed = false
    @edit = nil
    settings_get_info('root')
    add_flash(_("Edit of Customer Information was cancelled"))
    replace_right_cell('root')
  end

  def settings_server_validate
    if @sb[:active_tab] == "settings_server" && @edit[:new][:server] && ((@edit[:new][:server][:custom_support_url].nil? || @edit[:new][:server][:custom_support_url].strip == "") && (!@edit[:new][:server][:custom_support_url_description].nil? && @edit[:new][:server][:custom_support_url_description].strip != "") ||
        (@edit[:new][:server][:custom_support_url_description].nil? || @edit[:new][:server][:custom_support_url_description].strip == "") && (!@edit[:new][:server][:custom_support_url].nil? && @edit[:new][:server][:custom_support_url].strip != ""))
      add_flash(_("Custom Support URL and Description both must be entered."), :error)
    end
    if @sb[:active_tab] == "settings_server" && @edit[:new].fetch_path(:server, :remote_console_type) == "VNC"
      unless @edit[:new][:server][:vnc_proxy_port] =~ /^\d+$/ || @edit[:new][:server][:vnc_proxy_port].blank?
        add_flash(_("VNC Proxy Port must be numeric"), :error)
      end
      unless (@edit[:new][:server][:vnc_proxy_address].blank? &&
          @edit[:new][:server][:vnc_proxy_port].blank?) ||
             (!@edit[:new][:server][:vnc_proxy_address].blank? &&
                 !@edit[:new][:server][:vnc_proxy_port].blank?)
        add_flash(_("When configuring a VNC Proxy, both Address and Port are required"), :error)
      end
    end
  end

  def smartproxy_affinity_get_form_vars(id, checked)
    # Add/remove affinity based on the node that was checked
    server_id, child = id.split('__')

    if server_id.include?('svr')
      server_id = from_cid(server_id.sub('svr-', ''))
    else
      server_id.sub!('xx-', '')
    end
    all_children = @edit[:new][:children]
    server = @edit[:new][:servers][server_id.to_i]

    if child
      # A host/storage node was selected
      child_type, child_id = child.split('_')
      child_key = child_type.pluralize.to_sym

      children_update = child_id.blank? ? all_children[child_key] : [child_id.to_i]
      if checked
        server[child_key] += children_update
      else
        server[child_key] -= children_update
      end
    else
      # A server was selected
      if checked
        all_children.each { |k, v| server[k] = Set.new(v) }
      else
        server.each_value(&:clear)
      end
    end
  end

  def smartproxy_affinity_set_form_vars
    @edit = {}
    @edit[:new] = {}
    @edit[:current] = {}
    @edit[:key] = "#{@sb[:active_tab]}_edit__#{@selected_zone.id}"
    @sb[:selected_zone_id] = @selected_zone.id

    children = @edit[:current][:children] = {}
    children[:hosts] = @selected_zone.hosts.collect(&:id)
    children[:storages] = @selected_zone.storages.collect(&:id)
    servers = @edit[:current][:servers] = {}
    @selected_zone.miq_servers.each do |server|
      next unless server.is_a_proxy?
      servers[server.id] = {
        :hosts    => Set.new(server.vm_scan_host_affinity.collect(&:id)),
        :storages => Set.new(server.vm_scan_storage_affinity.collect(&:id))
      }
    end

    if @selected_zone.miq_servers.select(&:is_a_proxy?).present?
      @smartproxy_affinity_tree = TreeBuilderSmartproxyAffinity.new(:smartproxy_affinity,
                                                                    :smartproxy_affinity_tree,
                                                                    @sb,
                                                                    true,
                                                                    @selected_zone)
    end
    @edit[:new] = copy_hash(@edit[:current])
    session[:edit] = @edit
    @in_a_form = true
  end

  def smartproxy_affinity_update
    @changed = (@edit[:new] != @edit[:current])
    MiqServer.transaction do
      @edit[:new][:servers].each do |svr_id, children|
        server = MiqServer.find(svr_id)
        server.vm_scan_host_affinity = Host.where(:id =>  children[:hosts].to_a).to_a
        server.vm_scan_storage_affinity = Storage.where(:id => children[:storages].to_a).to_a
      end
    end
  rescue StandardError => bang
    add_flash(_("Error during Analysis Affinity save: %{message}") % {:message => bang.message}, :error)
  else
    add_flash(_("Analysis Affinity was saved"))
  end

  # load @edit from session and then update @edit from params based on active_tab
  def settings_get_form_vars
    settings_load_edit
    return unless @edit
    @in_a_form = true
    nodes = x_node.downcase.split("-")
    cls = nodes.first.split('__').last == "z" ? Zone : MiqServer

    params = self.params
    new = @edit[:new]

    # WTF? here we can have a Zone or a MiqServer, what about Region? --> rescue from exception
    @selected_server = (cls.find(from_cid(nodes.last)) rescue nil)

    case @sb[:active_tab]                                               # No @edit[:current].config for Filters since there is no config file
    when 'settings_rhn_edit'
      [:proxy_address, :use_proxy, :proxy_userid, :proxy_password, :proxy_verify, :register_to, :server_url, :repo_name,
       :customer_org, :customer_org_display, :customer_userid, :customer_password, :customer_verify].each do |key|
        new[key] = params[key] if params[key]
      end
      if params[:register_to] || params[:action] == "repo_default_name"
        new[:repo_name] = reset_repo_name_from_default
      end
      @changed = (new != @edit[:current])
    when "settings_server"                                                # Server Settings tab
      if !params[:smtp_test_to].nil? && params[:smtp_test_to] != ""
        @sb[:new_to] = params[:smtp_test_to]
      elsif params[:smtp_test_to] && (params[:smtp_test_to] == "" || params[:smtp_test_to].nil?)
        @sb[:new_to] = nil
      end
      new[:smtp][:authentication] = params[:smtp_authentication] if params[:smtp_authentication]
      new[:server][:locale] = params[:locale] if params[:locale]
      @smtp_auth_none = (new[:smtp][:authentication] == "none")
      if !new[:smtp][:host].blank? && !new[:smtp][:port].blank? && !new[:smtp][:domain].blank? &&
         (!new[:smtp][:user_name].blank? || new[:smtp][:authentication] == "none") &&
         !new[:smtp][:from].blank? && !@sb[:new_to].blank?
        @test_email_button = true
      else
        @test_email_button = false
      end
      @sb[:roles] = new[:server][:role].split(",")
      params.each do |var, val|
        if var.starts_with?("server_roles_") && val.to_s == "true"
          @sb[:roles].push(var.split("server_roles_").last) unless @sb[:roles].include?(var.split("server_roles_").last)
        elsif var.starts_with?("server_roles_") && val.downcase == "false"
          @sb[:roles].delete(var.split("server_roles_").last)
        end
        server_role = @sb[:roles].sort.join(",")
        new[:server][:role] = server_role
        session[:selected_roles] = new[:server][:role].split(",") if !new[:server].nil? && !new[:server][:role].nil?
      end
      @host_choices = session[:host_choices]
      new[:server][:remote_console_type] = params[:console_type] if params[:console_type]

      new[:ntp][:server] ||= []
      new[:ntp][:server][0] = params[:ntp_server_1] if params[:ntp_server_1]
      new[:ntp][:server][1] = params[:ntp_server_2] if params[:ntp_server_2]
      new[:ntp][:server][2] = params[:ntp_server_3] if params[:ntp_server_3]

      new[:server][:custom_support_url] = params[:custom_support_url].strip if params[:custom_support_url]
      new[:server][:custom_support_url_description] = params[:custom_support_url_description] if params[:custom_support_url_description]
    when "settings_authentication"                                        # Authentication tab
      auth = new[:authentication]
      @sb[:form_vars][:session_timeout_mins] = params[:session_timeout_mins] if params[:session_timeout_mins]
      @sb[:form_vars][:session_timeout_hours] = params[:session_timeout_hours] if params[:session_timeout_hours]
      new[:session][:timeout] = @sb[:form_vars][:session_timeout_hours].to_i * 3600 + @sb[:form_vars][:session_timeout_mins].to_i * 60 if params[:session_timeout_hours] || params[:session_timeout_mins]
      @sb[:newrole] = (params[:ldap_role].to_s == "1") if params[:ldap_role]
      @sb[:new_amazon_role] = (params[:amazon_role].to_s == "1") if params[:amazon_role]
      @sb[:new_httpd_role] = (params[:httpd_role].to_s == "1") if params[:httpd_role]
      if params[:authentication_user_type] && params[:authentication_user_type] != auth[:user_type]
        @authusertype_changed = true
      end
      auth[:user_suffix] = params[:authentication_user_suffix] if params[:authentication_user_suffix]
      auth[:domain_prefix] = params[:authentication_domain_prefix] if params[:authentication_domain_prefix]
      if @sb[:newrole] != auth[:ldap_role]
        auth[:ldap_role] = @sb[:newrole]
        @authldaprole_changed = true
      end
      if @sb[:new_amazon_role] != auth[:amazon_role]
        auth[:amazon_role] = @sb[:new_amazon_role]
      end
      if @sb[:new_httpd_role] != auth[:httpd_role]
        auth[:httpd_role] = @sb[:new_httpd_role]
      end
      if params[:authentication_mode] && params[:authentication_mode] != auth[:mode]
        if params[:authentication_mode] == "ldap"
          params[:authentication_ldapport] = "389"
          @sb[:newrole] = auth[:ldap_role] = @edit[:current].config[:authentication][:ldap_role]
          @authldapport_reset = true
        elsif params[:authentication_mode] == "ldaps"
          params[:authentication_ldapport] = "636"
          @sb[:newrole] = auth[:ldap_role] = @edit[:current].config[:authentication][:ldap_role]
          @authldapport_reset = true
        else
          @sb[:newrole] = auth[:ldap_role] = false    # setting it to false if database was selected to hide user_proxies box
        end
        @authmode_changed = true
      end
      if (params[:authentication_ldaphost_1] || params[:authentication_ldaphost_2] || params[:authentication_ldaphost_3]) ||
         (params[:authentication_ldapport] != auth[:ldapport])
        @reset_verify_button = true
      end
      if (params[:authentication_amazon_key] != auth[:amazon_key]) ||
         (params[:authentication_amazon_secret] != auth[:amazon_secret])
        @reset_amazon_verify_button = true
      end

      auth[:amazon_key] = params[:authentication_amazon_key] if params[:authentication_amazon_key]
      auth[:amazon_secret] = params[:authentication_amazon_secret] if params[:authentication_amazon_secret]
      auth[:ldaphost] ||= []
      auth[:ldaphost][0] = params[:authentication_ldaphost_1] if params[:authentication_ldaphost_1]
      auth[:ldaphost][1] = params[:authentication_ldaphost_2] if params[:authentication_ldaphost_2]
      auth[:ldaphost][2] = params[:authentication_ldaphost_3] if params[:authentication_ldaphost_3]

      auth[:follow_referrals] = (params[:follow_referrals].to_s == "1") if params[:follow_referrals]
      auth[:get_direct_groups] = (params[:get_direct_groups].to_s == "1") if params[:get_direct_groups]
      if params[:user_proxies] && params[:user_proxies][:mode] != auth[:user_proxies][0][:mode]
        if params[:user_proxies][:mode] == "ldap"
          params[:user_proxies][:ldapport] = "389"
          @user_proxies_port_reset = true
        elsif params[:user_proxies][:mode] == "ldaps"
          params[:user_proxies][:ldapport] = "636"
          @user_proxies_port_reset = true
        end
        @authmode_changed = true
      end
      auth[:sso_enabled] = (params[:sso_enabled].to_s == "1") if params[:sso_enabled]
      auth[:saml_enabled] = (params[:saml_enabled].to_s == "1") if params[:saml_enabled]
      auth[:local_login_disabled] = (params[:local_login_disabled].to_s == "1") if params[:local_login_disabled]
      auth[:default_group_for_users] = params[:authentication_default_group_for_users] if params[:authentication_default_group_for_users]
    when "settings_workers"                                       # Workers Settings tab
      wb  = new.config[:workers][:worker_base]
      qwb = wb[:queue_worker_base]

      w = qwb[:generic_worker]
      w[:count] = params[:generic_worker_count].to_i if params[:generic_worker_count]
      w[:memory_threshold] = params[:generic_worker_threshold] if params[:generic_worker_threshold]

      w = qwb[:priority_worker]
      w[:count] = params[:priority_worker_count].to_i if params[:priority_worker_count]
      w[:memory_threshold] = params[:priority_worker_threshold] if params[:priority_worker_threshold]

      w = qwb[:ems_metrics_collector_worker][:defaults]
      w[:count] = params[:ems_metrics_collector_worker_count].to_i if params[:ems_metrics_collector_worker_count]
      w[:memory_threshold] = params[:ems_metrics_collector_worker_threshold] if params[:ems_metrics_collector_worker_threshold]

      w = qwb[:ems_metrics_processor_worker]
      w[:count] = params[:ems_metrics_processor_worker_count].to_i if params[:ems_metrics_processor_worker_count]
      w[:memory_threshold] = params[:ems_metrics_processor_worker_threshold] if params[:ems_metrics_processor_worker_threshold]

      w = qwb[:ems_refresh_worker][:defaults]
      w[:memory_threshold] = params[:ems_refresh_worker_threshold] if params[:ems_refresh_worker_threshold]

      w = wb[:event_catcher]
      w[:memory_threshold] = params[:event_catcher_threshold] if params[:event_catcher_threshold]

      w = wb[:vim_broker_worker]
      w[:memory_threshold] = params[:vim_broker_worker_threshold] if params[:vim_broker_worker_threshold]

      w = qwb[:smart_proxy_worker]
      w[:count] = params[:proxy_worker_count].to_i if params[:proxy_worker_count]
      w[:memory_threshold] = params[:proxy_worker_threshold] if params[:proxy_worker_threshold]

      w = wb[:ui_worker]
      w[:count] = params[:ui_worker_count].to_i if params[:ui_worker_count]

      w = qwb[:reporting_worker]
      w[:count] = params[:reporting_worker_count].to_i if params[:reporting_worker_count]
      w[:memory_threshold] = params[:reporting_worker_threshold] if params[:reporting_worker_threshold]

      w = wb[:web_service_worker]
      w[:count] = params[:web_service_worker_count].to_i if params[:web_service_worker_count]
      w[:memory_threshold] = params[:web_service_worker_threshold] if params[:web_service_worker_threshold]

      w = wb[:websocket_worker]
      w[:count] = params[:websocket_worker_count].to_i if params[:websocket_worker_count]
    when "settings_custom_logos"                                            # Custom Logo tab
      new[:server][:custom_logo] = (params[:server_uselogo] == "1") if params[:server_uselogo]
      new[:server][:custom_login_logo] = (params[:server_useloginlogo] == "1") if params[:server_useloginlogo]
      new[:server][:use_custom_login_text] = (params[:server_uselogintext] == "true") if params[:server_uselogintext]
      if params[:login_text]
        new[:server][:custom_login_text] = params[:login_text]
        @login_text_changed = new[:server][:custom_login_text] != @edit[:current].config[:server][:custom_login_text].to_s
      end
    when "settings_smartproxy"                                        # SmartProxy Defaults tab
      @sb[:form_vars][:agent_heartbeat_frequency_mins] = params[:agent_heartbeat_frequency_mins] if params[:agent_heartbeat_frequency_mins]
      @sb[:form_vars][:agent_heartbeat_frequency_secs] = params[:agent_heartbeat_frequency_secs] if params[:agent_heartbeat_frequency_secs]
      @sb[:form_vars][:agent_log_wraptime_days] = params[:agent_log_wraptime_days] if params[:agent_log_wraptime_days]
      @sb[:form_vars][:agent_log_wraptime_hours] = params[:agent_log_wraptime_hours] if params[:agent_log_wraptime_hours]
      agent = new[:agent]
      agent_log = agent[:log]
      agent[:heartbeat_frequency] = @sb[:form_vars][:agent_heartbeat_frequency_mins].to_i * 60 + @sb[:form_vars][:agent_heartbeat_frequency_secs].to_i if params[:agent_heartbeat_frequency_mins] || params[:agent_heartbeat_frequency_secs]
      agent[:readonly] = (params[:agent_readonly] == "1") if params[:agent_readonly]
      agent_log[:level] = params[:agent_log_level] if params[:agent_log_level]
      agent_log[:wrap_size] = params[:agent_log_wrapsize] if params[:agent_log_wrapsize]
      agent_log[:wrap_time] = @sb[:form_vars][:agent_log_wraptime_days].to_i * 3600 * 24 + @sb[:form_vars][:agent_log_wraptime_hours].to_i * 3600 if params[:agent_log_wraptime_days] || params[:agent_log_wraptime_hours]
    when "settings_advanced"                                        # Advanced tab
      if params[:file_data]                        # If save sent in the file data
        new[:file_data] = params[:file_data]          # Put into @edit[:new] hash
      else
        new[:file_data] += "..."                      # Update the new data to simulate a change
      end
    end

    # This section scoops up the config second level keys changed in the UI
    unless %w(settings_advanced settings_rhn_edit settings_smartproxy_affinity).include?(@sb[:active_tab])
      @edit[:current].config.each_key do |category|
        @edit[:current].config[category].symbolize_keys.each_key do |key|
          if category == :smtp && key == :enable_starttls_auto  # Checkbox is handled differently
            new[category][key] = params["#{category}_#{key}"] == "true" if params.key?("#{category}_#{key}")
          else
            new[category][key] = params["#{category}_#{key}"] if params["#{category}_#{key}"]
          end
        end
        auth[:user_proxies][0] = copy_hash(params[:user_proxies]) if params[:user_proxies] && category == :authentication
      end
    end
  end

  # Load the @edit object from session based on which config screen we are on
  def settings_load_edit
    if x_node.split("-").first == "z"
      # if zone node is selected
      return unless load_edit("#{@sb[:active_tab]}_edit__#{@sb[:selected_zone_id]}", "replace_cell__explorer")
      @prev_selected_svr = session[:edit][:new][:selected_server]
    elsif @sb[:active_tab] == 'settings_rhn_edit'
      return unless load_edit("#{@sb[:active_tab]}__#{params[:id]}", "replace_cell__explorer")
    else
      if %w(settings_server settings_authentication settings_workers
            settings_custom_logos settings_advanced).include?(@sb[:active_tab])
        return unless load_edit("settings_#{params[:id]}_edit__#{@sb[:selected_server_id]}", "replace_cell__explorer")
      end
    end
  end

  def settings_set_form_vars
    if x_node.split("-").first == "z"
      @right_cell_text = my_zone_name == @selected_zone.name ?
        _("Settings %{model} \"%{name}\" (current)") % {:name  => @selected_zone.description,
                                                        :model => ui_lookup(:model => @selected_zone.class.to_s)} :
        _("Settings %{model} \"%{name}\"") % {:name  => @selected_zone.description,
                                              :model => ui_lookup(:model => @selected_zone.class.to_s)}
    else
      @right_cell_text = my_server_id == @sb[:selected_server_id] ?
        _("Settings %{model} \"%{name}\" (current)") % {:name  => "#{@selected_server.name} [#{@selected_server.id}]",
                                                        :model => ui_lookup(:model => @selected_server.class.to_s)} :
        _("Settings %{model} \"%{name}\"") % {:name  => "#{@selected_server.name} [#{@selected_server.id}]",
                                              :model => ui_lookup(:model => @selected_server.class.to_s)}
    end
    case @sb[:active_tab]
    when "settings_server"                                  # Server Settings tab
      @edit = {}
      @edit[:new] = {}
      @edit[:current] = MiqServer.find(@sb[:selected_server_id]).get_config("vmdb")
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @sb[:new_to] = nil
      @sb[:newrole] = false
      session[:server_zones] = []
      zones = Zone.all
      zones.each do |zone|
        session[:server_zones].push(zone.name)
      end
      @edit[:current].config[:server][:role] = @edit[:current].config[:server][:role] ? @edit[:current].config[:server][:role].split(",").sort.join(",") : ""
      @edit[:current].config[:server][:timezone] = "UTC" if @edit[:current].config[:server][:timezone].blank?
      @edit[:current].config[:server][:locale] = "default" if @edit[:current].config[:server][:locale].blank?
      @edit[:current].config[:server][:remote_console_type] ||= "MKS"
      @edit[:current].config[:server][:vnc_proxy_address] ||= nil
      @edit[:current].config[:server][:vnc_proxy_port] ||= nil
      @edit[:current].config[:smtp][:enable_starttls_auto] = GenericMailer.default_for_enable_starttls_auto if @edit[:current].config[:smtp][:enable_starttls_auto].nil?
      @edit[:current].config[:smtp][:openssl_verify_mode] ||= nil
      @edit[:current].config[:ntp] ||= {}
      @edit[:current].config[:ntp][:server] ||= []
      @in_a_form = true
    when "settings_authentication"        # Authentication tab
      @edit = {}
      @edit[:new] = {}
      @edit[:current] = {}
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @edit[:current] = MiqServer.find(@sb[:selected_server_id]).get_config("vmdb")
      # Avoid thinking roles change when not yet set
      @edit[:current].config[:authentication][:ldap_role] ||= false
      @edit[:current].config[:authentication][:amazon_role] ||= false
      @edit[:current].config[:authentication][:httpd_role] ||= false
      @sb[:form_vars] = {}
      @sb[:form_vars][:session_timeout_hours] = @edit[:current].config[:session][:timeout] / 3600
      @sb[:form_vars][:session_timeout_mins] = (@edit[:current].config[:session][:timeout] % 3600) / 60
      @edit[:current].config[:authentication][:ldaphost] = @edit[:current].config[:authentication][:ldaphost].to_miq_a
      @edit[:current].config[:authentication][:user_proxies] ||= [{}]
      @edit[:current].config[:authentication][:follow_referrals] ||= false
      @edit[:current].config[:authentication][:sso_enabled] ||= false
      @edit[:current].config[:authentication][:saml_enabled] ||= false
      @edit[:current].config[:authentication][:local_login_disabled] ||= false
      @sb[:newrole] = @edit[:current].config[:authentication][:ldap_role]
      @sb[:new_amazon_role] = @edit[:current].config[:authentication][:amazon_role]
      @sb[:new_httpd_role] = @edit[:current].config[:authentication][:httpd_role]
      @in_a_form = true
    when "settings_smartproxy_affinity"                     # SmartProxy Affinity tab
      smartproxy_affinity_set_form_vars
    when "settings_workers"                                 # Worker Settings tab
      # getting value in "1.megabytes" bytes from backend, converting it into "1 MB" to display in UI, and then later convert it into "1.megabytes" to before saving it back into config.
      # need to create two copies of config new/current set_worker_setting! is a instance method, need @edit[:new] to be config class to set count/memory_threshold, can't run method against hash
      @edit = {}
      @edit[:new] = {}
      @edit[:current] = {}
      @edit[:current] = MiqServer.find(@sb[:selected_server_id]).get_config
      @edit[:new] = MiqServer.find(@sb[:selected_server_id]).get_config
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @sb[:threshold] = []
      (200.megabytes...550.megabytes).step(50.megabytes) { |x| @sb[:threshold] << number_to_human_size(x, :significant => false) }
      (600.megabytes...1000.megabytes).step(100.megabytes) { |x| @sb[:threshold] << number_to_human_size(x, :significant => false) }    # adding values in 100 MB increments from 600 to 1gb, dividing in two statements else it puts 1000MB instead of 1GB in pulldown
      (1.gigabytes...1.5.gigabytes).step(100.megabytes) { |x| @sb[:threshold] << number_to_human_size(x, :significant => false) }   # adding values in 100 MB increments from 1gb to 1.5 gb

      cwb = @edit[:current].config[:workers][:worker_base] ||= {}
      qwb = (cwb[:queue_worker_base] ||= {})
      w = (qwb[:generic_worker] ||= {})
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqGenericWorker, :count) || 2
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqGenericWorker, :memory_threshold)) || rails_method_to_human_size(400.megabytes)
      @sb[:generic_threshold] = []
      @sb[:generic_threshold] = copy_array(@sb[:threshold])

      w = (qwb[:priority_worker] ||= {})
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqPriorityWorker, :count) || 2
      w[:memory_threshold] =  rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqPriorityWorker, :memory_threshold)) || rails_method_to_human_size(200.megabytes)
      @sb[:priority_threshold] = []
      @sb[:priority_threshold] = copy_array(@sb[:threshold])

      qwb[:ems_metrics_collector_worker] ||= {}
      qwb[:ems_metrics_collector_worker][:defaults] ||= {}
      w = qwb[:ems_metrics_collector_worker][:defaults]
      raw = @edit[:current].get_raw_worker_setting(:MiqEmsMetricsCollectorWorker)
      w[:count] = raw[:defaults][:count] || 2
      w[:memory_threshold] = rails_method_to_human_size(raw[:defaults][:memory_threshold] || 400.megabytes)
      @sb[:ems_metrics_collector_threshold] = []
      @sb[:ems_metrics_collector_threshold] = copy_array(@sb[:threshold])

      w = (qwb[:ems_metrics_processor_worker] ||= {})
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqEmsMetricsProcessorWorker, :count) || 2
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqEmsMetricsProcessorWorker, :memory_threshold)) || rails_method_to_human_size(200.megabytes)
      @sb[:ems_metrics_processor_threshold] = []
      @sb[:ems_metrics_processor_threshold] = copy_array(@sb[:threshold])

      w = (qwb[:smart_proxy_worker] ||= {})
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqSmartProxyWorker, :count) || 3
      w[:memory_threshold] =  rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqSmartProxyWorker, :memory_threshold)) || rails_method_to_human_size(400.megabytes)
      @sb[:smart_proxy_threshold] = []
      @sb[:smart_proxy_threshold] = copy_array(@sb[:threshold])

      qwb[:ems_refresh_worker] ||= {}
      qwb[:ems_refresh_worker][:defaults] ||= {}
      w = qwb[:ems_refresh_worker][:defaults]
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqEmsRefreshWorker, [:defaults, :memory_threshold])) || rails_method_to_human_size(400.megabytes)
      @sb[:ems_refresh_threshold] = []
      (200.megabytes...550.megabytes).step(50.megabytes) { |x| @sb[:ems_refresh_threshold] << number_to_human_size(x, :significant => false) }
      (600.megabytes..900.megabytes).step(100.megabytes) { |x| @sb[:ems_refresh_threshold] << number_to_human_size(x, :significant => false) }
      (1.gigabytes..2.9.gigabytes).step(1.gigabyte / 10) { |x| @sb[:ems_refresh_threshold] << number_to_human_size(x, :significant => false) }
      (3.gigabytes..10.gigabytes).step(512.megabytes) { |x| @sb[:ems_refresh_threshold] << number_to_human_size(x, :significant => false) }

      wb = @edit[:current].config[:workers][:worker_base]
      w = (wb[:event_catcher] ||= {})
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqEventCatcher, :memory_threshold)) || rails_method_to_human_size(1.gigabytes)
      @sb[:event_catcher_threshold] = []
      (500.megabytes...1000.megabytes).step(100.megabytes) { |x| @sb[:event_catcher_threshold] << number_to_human_size(x, :significant => false) }
      (1.gigabytes..2.9.gigabytes).step(1.gigabyte / 10) { |x| @sb[:event_catcher_threshold] << number_to_human_size(x, :significant => false) }
      (3.gigabytes..10.gigabytes).step(512.megabytes) { |x| @sb[:event_catcher_threshold] << number_to_human_size(x, :significant => false) }

      w = (wb[:vim_broker_worker] ||= {})
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqVimBrokerWorker, :memory_threshold)) || rails_method_to_human_size(1.gigabytes)
      @sb[:vim_broker_threshold] = []
      (500.megabytes..900.megabytes).step(100.megabytes) { |x| @sb[:vim_broker_threshold] << number_to_human_size(x, :significant => false) }
      (1.gigabytes..2.9.gigabytes).step(1.gigabyte / 10) { |x| @sb[:vim_broker_threshold] << number_to_human_size(x, :significant => false) }
      (3.gigabytes..10.gigabytes).step(512.megabytes) { |x| @sb[:vim_broker_threshold] << number_to_human_size(x, :significant => false) }

      w = (wb[:ui_worker] ||= {})
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqUiWorker, :count) || 2

      w = (qwb[:reporting_worker] ||= {})
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqReportingWorker, :count) || 2
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqReportingWorker, :memory_threshold)) || rails_method_to_human_size(400.megabytes)
      @sb[:reporting_threshold] = []
      @sb[:reporting_threshold] = copy_array(@sb[:threshold])

      w = (wb[:web_service_worker] ||= {})
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqWebServiceWorker, :count) || 2
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqWebServiceWorker, :memory_threshold)) || rails_method_to_human_size(400.megabytes)
      @sb[:web_service_threshold] = []
      @sb[:web_service_threshold] = copy_array(@sb[:threshold])

      w = (wb[:websocket_worker] ||= {})
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqWebsocketWorker, :count) || 2

      @edit[:new].config = copy_hash(@edit[:current].config)
      session[:log_depot_default_verify_status] = true
      @in_a_form = true
    when "settings_custom_logos"                                  # Custom Logo tab
      @edit = {}
      @edit[:new] = {}
      @edit[:current] = {}
      @edit[:current] = VMDB::Config.new("vmdb")                # Get the vmdb configuration settings
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      if @edit[:current].config[:server][:custom_logo].nil?
        @edit[:current].config[:server][:custom_logo] = false # Set default custom_logo flag
      end
      @logo_file = @@logo_file
      @login_logo_file = @@login_logo_file
      @in_a_form = true
    when "settings_advanced"                                  # Advanced yaml editor
      @edit = {}
      @edit[:current] = {:file_data => VMDB::Config.get_file}
      @edit[:new] = copy_hash(@edit[:current])
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @in_a_form = true
    end
    if %w(settings_server settings_authentication settings_custom_logos).include?(@sb[:active_tab]) &&
       x_node.split("-").first != "z"
      @edit[:current].config.each_key do |category|
        @edit[:new][category] = copy_hash(@edit[:current].config[category])
      end
      if @sb[:active_tab] == "settings_server"
        session[:selected_roles] = @edit[:new][:server][:role].split(",") if !@edit[:new][:server].nil? && !@edit[:new][:server][:role].nil?
        server_roles = MiqServer.licensed_roles           # Get the roles this server is licensed for
        server_roles.delete_if { |r| r.name == "database_owner" }
        session[:server_roles] = {}
        server_roles.each do |sr|
          session[:server_roles][sr["name"]] = sr["description"] unless session[:server_roles].key?(sr["name"])
        end
      end
    end
    session[:edit] = @edit
  end

  # Get information for a settings node
  def settings_get_info(nodetype = x_node)
    nodes = nodetype.downcase.split("-")
    case nodes[0]
    when "root"
      @right_cell_text = _("Settings %{model} \"%{name}\"") %
                         {:name  => "#{MiqRegion.my_region.description} [#{MiqRegion.my_region.region}]",
                          :model => ui_lookup(:model => "MiqRegion")}
      case @sb[:active_tab]
      when "settings_details"
        settings_set_view_vars
      when "settings_cu_collection"                                 # C&U collection settings
        cu_build_edit_screen
        @in_a_form = true
      when "settings_co_categories"
        category_get_all
      when "settings_co_tags"
        # dont hide the disabled categories, so user can remove tags from the disabled ones
        cats = Classification.categories.sort_by(&:description)  # Get the categories, sort by name
        @cats = {}                                        # Classifications array for first chooser
        cats.each do |c|
          @cats[c.description] = c.name unless c.read_only?    # Show the non-read_only categories
        end
        @cat = cats.first
        ce_build_screen                                         # Build the Classification Edit screen
      when "settings_import_tags"
        @edit = {}
        @edit[:new] = {}
        @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
        add_flash(_("Locate and upload a file to start the import process"), :info)
        @in_a_form = true
      when "settings_import"                                  # Import tab
        @edit = {}
        @edit[:new] = {}
        @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
        @edit[:new][:upload_type] = nil
        @sb[:good] = nil unless @sb[:show_button]
        add_flash(_("Choose the type of custom variables to be imported"))
        @in_a_form = true
      when "settings_rhn"
        @edit = session[:edit] || {}
        @edit[:new] ||= {}
        @edit[:new][:servers] ||= {}
        @customer = rhn_subscription
        @buttons_on = @edit[:new][:servers].detect { |_, value| !!value }
        @updates = rhn_update_information
      end
    when "xx"
      case nodes[1]
      when "z"
        @right_cell_text = _("Settings %{model}") % {:model => ui_lookup(:models => "Zone")}
        @zones = Zone.in_my_region
      when "sis"
        @right_cell_text = _("Settings %{model}") % {:model => ui_lookup(:models => "ScanItemSet")}
        aps_list
      when "msc"
        @right_cell_text = _("Settings %{model}") % {:model => ui_lookup(:models => "MiqSchedule")}
        schedules_list
      when "l"
        @right_cell_text = _("Settings %{model}") % {:model => ui_lookup(:models => "LdapRegion")}
        ldap_regions_list
      end
    when "svr"
      # @sb[:tabform] = "operations_1" if @sb[:selected_server] && @sb[:selected_server].id != nodetype.downcase.split("-").last.to_i #reset tab if server node was changed, current server has 10 tabs, current active tab may not be available for other server nodes.
      #     @sb[:selected_server] = MiqServer.find(from_cid(nodetype.downcase.split("-").last))
      @selected_server = MiqServer.find(from_cid(nodes.last))
      @sb[:selected_server_id] = @selected_server.id
      settings_set_form_vars
    when "msc"
      @record = @selected_schedule = MiqSchedule.find(from_cid(nodes.last))
      @right_cell_text = _("Settings %{model} \"%{name}\"") % {:name  => @selected_schedule.name,
                                                               :model => ui_lookup(:model => "MiqSchedule")}
      schedule_show
    when "ld", "lr"
      nodes = nodetype.split('-')
      if nodes[0] == "lr"
        @record = @selected_lr = LdapRegion.find(from_cid(nodes[1]))
        @right_cell_text = _("Settings %{model} \"%{name}\"") % {:name  => @selected_lr.name,
                                                                 :model => ui_lookup(:model => "LdapRegion")}
        ldap_region_show
      else
        @record = @selected_ld = LdapDomain.find(from_cid(nodes[1]))
        @right_cell_text = _("Settings %{model} \"%{name}\"") % {:name  => @selected_ld.name,
                                                                 :model => ui_lookup(:model => "LdapDomain")}
        ldap_domain_show
      end
    when "sis"
      @record = @selected_scan = ScanItemSet.find(from_cid(nodes.last))
      @right_cell_text = _("Settings %{model} \"%{name}\"") % {:name  => @selected_scan.name,
                                                               :model => ui_lookup(:model => "ScanItemSet")}
      ap_show
    when "z"
      @servers = []
      @record = @zone = @selected_zone = Zone.find(from_cid(nodes.last))
      @sb[:tab_label] = @selected_zone.description
      @right_cell_text = my_zone_name == @selected_zone.name ?
          _("Settings %{model} \"%{name}\" (current)") % {:name  => @selected_zone.description,
                                                          :model => ui_lookup(:model => @selected_zone.class.to_s)} :
          _("Settings %{model} \"%{name}\"") % {:name  => @selected_zone.description,
                                                :model => ui_lookup(:model => @selected_zone.class.to_s)}
      MiqServer.all.each do |ms|
        if ms.zone_id == @selected_zone.id
          @servers.push(ms)
        end
      end
      smartproxy_affinity_set_form_vars if @sb[:active_tab] == "settings_smartproxy_affinity"
    end
  end

  # Build the main Settings tree
  def settings_build_tree
    TreeBuilderOpsSettings.new("settings_tree", "settings", @sb)
  end

  def settings_set_view_vars
    if @sb[:active_tab] == "settings_details"
      # Enterprise Details tab
      @scan_items = ScanItemSet.all
      @zones = Zone.in_my_region
      @ldap_regions = LdapRegion.in_my_region
      @miq_schedules = MiqSchedule.where("(prod_default != 'system' or prod_default is null) and adhoc IS NULL")
                       .sort_by { |s| s.name.downcase }
    end
  end
end
