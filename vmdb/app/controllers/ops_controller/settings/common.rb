module OpsController::Settings::Common
  extend ActiveSupport::Concern

  logo_dir = File.expand_path(File.join(Rails.root, "public/upload"))
  Dir.mkdir logo_dir unless File.exists?(logo_dir)
  @@logo_file = File.join(logo_dir, "custom_logo.png")
  @@login_logo_file = File.join(logo_dir, "custom_login_logo.png")

  # AJAX driven routine to check for changes in ANY field on the form
  def settings_form_field_changed
    tab = params[:id] ? "settings_#{params[:id]}" : nil # workaround to prevent an error that happens when IE sends a transaction when tab is changed when there is text_area in the form, checking for tab id
    if tab && tab != @sb[:active_tab] && params[:id] != 'new'
      render :nothing => true
      return
    end

    @prev_selected_dbtype = session[:edit][:new][:name] if @sb[:active_tab] == "settings_database"
    settings_get_form_vars
    return unless @edit
    @assigned_filters = []
    case @sb[:active_tab] # Server, DB edit forms
    when 'settings_server', 'settings_authentication', 'settings_host',
         'settings_custom_logos', 'settings_smartproxy'
      @changed = (@edit[:new] != @edit[:current].config)
      if params[:console_type]
        get_smartproxy_choices
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
        add_flash(I18n.t("flash.ops.settings.changing_ui_worker_count"), :warning)
      end
    when 'settings_maintenance'                             # Maintenance tab
    when 'settings_smartproxy'                              # SmartProxy Defaults tab
    when 'settings_advanced'                                # Advanced yaml edit
      @changed = (@edit[:new] != @edit[:current])
      if params[:file_name]                                 # If new file was selected
        @refresh_div     = 'settings_advanced'              # Replace main area
        @refresh_partial = 'settings_advanced_tab'
      end
    end

    render :update do |page|                    # Use JS to update the display
      page.replace_html(@refresh_div, :partial => @refresh_partial) if @refresh_div

      case @sb[:active_tab]
      when 'settings_server'
        if @test_email_button
          page << "$('email_verify_button_off').hide();"
          page << "$('email_verify_button_on').show();"
        else
          page << "$('email_verify_button_on').hide();"
          page << "$('email_verify_button_off').show();"
        end

        verb = @smtp_auth_none ? 'disable' : 'enable'
        page << "$('smtp_user_name').#{verb}();"
        page << "$('smtp_password').#{verb}();"

        if @changed || @login_text_changed
          page << "if ($('server_options_on')) $('server_options_on').hide();"
          page << "if ($('server_options_off')) $('server_options_off').show();"
        else
          page << "if ($('server_options_off')) $('server_options_off').hide();"
          page << "if ($('server_options_on')) $('server_options_on').show();"
        end
      when 'settings_advanced'
        if @changed || @login_text_changed
          page << "$('message_on').show();"
          page << "$('message_off').hide();"
        end
      when 'settings_authentication'
        if @authmode_changed
          if ["ldap","ldaps"].include?(@edit[:new][:authentication][:mode])
            page << "$('ldap_div').show();"
            page << "$('ldap_role_div').show();"
            page << "$('user_proxies_div').show();" if @edit[:new][:authentication][:ldap_role]
          else
            page << "$('ldap_div').hide();"
            page << "$('ldap_role_div').hide();"
            page << "$('user_proxies_div').hide();"
          end
          verb = @edit[:new][:authentication][:mode] == 'amazon' ? 'show' : 'hide'
          page << "$('amazon_div').#{verb}();"
          page << "$('amazon_role_div').#{verb}();"

          verb = @edit[:new][:authentication][:mode] == 'httpd' ? 'show' : 'hide'
          page << "$('httpd_role_div').#{verb}();"
        end
        if @authusertype_changed
          if @edit[:new][:authentication][:user_type] == "dn-cn"
            page << "$('upn-mail_prefix').hide();"
            page << "$('dn-uid_prefix').hide();"
            page << "$('dn-cn_prefix').show();"
          elsif @edit[:new][:authentication][:user_type] == "dn-uid"
            page << "$('upn-mail_prefix').hide();"
            page << "$('dn-cn_prefix').hide();"
            page << "$('dn-uid_prefix').show();"
          else
            page << "$('dn-cn_prefix').hide();"
            page << "$('dn-uid_prefix').hide();"
            page << "$('upn-mail_prefix').show();"
          end
        end
        if @authldaprole_changed
          verb = @edit[:new][:authentication][:ldap_role] ? 'show' : 'hide'
          page << "$('user_proxies_div').#{verb}();"
          page << "$('ldap_role_details_div').#{verb}();"
        end
        if @authldapport_reset
          page << "$('authentication_ldapport').value = '#{@edit[:new][:authentication][:ldapport]}'"
        end
        if @reset_verify_button
          if !@edit[:new][:authentication][:ldaphost].empty? && @edit[:new][:authentication][:ldapport] != nil
            page << "$('verify_button_off').hide();"
            page << "$('verify_button_on').show();"
          else
            page << "$('verify_button_on').hide();"
            page << "$('verify_button_off').show();"
          end
        end
        if @reset_amazon_verify_button
          if @edit[:new][:authentication][:amazon_key] != nil && @edit[:new][:authentication][:amazon_secret] != nil
            page << "$('amazon_verify_button_off').hide();"
            page << "$('amazon_verify_button_on').show();"
          else
            page << "$('amazon_verify_button_on').hide();"
            page << "$('amazon_verify_button_off').show();"
          end
        end
      when 'settings_workers'
        if @edit[:default_verify_status] != session[:log_depot_default_verify_status]
          session[:log_depot_default_verify_status] = @edit[:default_verify_status]
          verb = @edit[:default_verify_status] ? 'show' : 'hide'
          page << "miqValidateButtons('#{verb}', 'default_');"
        end
        if @edit[:new].config[:workers][:worker_base][:ui_worker][:count] != @edit[:current].config[:workers][:worker_base][:ui_worker][:count]
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        page.replace_html('pwd_note', @edit[:default_verify_status] ? '' : "* Passwords don't match.")
      when 'settings_database'
        # database tab
        @changed = (@edit[:new] != @edit[:current])
        # only disable validate button if passwords don't match
        if @edit[:new][:password] == @edit[:new][:verify]
          page << "$('validate_button_off').hide();"
          page << "$('validate_button_on').show();"
        else
          page << "$('validate_button_on').hide();"
          page << "$('validate_button_off').show();"
        end
        page.replace_html("settings_database", :partial=>"settings_database_tab") if @prev_selected_dbtype != @edit[:new][:name]
      end

      page << javascript_for_miq_button_visibility(@changed || @login_text_changed)
    end
  end

  def settings_update
    if params[:button] == "verify"                                      # User doing ldap verify
      settings_get_form_vars
      return unless @edit
      @validate = MiqServer.find(@sb[:selected_server_id]).get_config("vmdb")
      @validate.config.each_key do |category|
        @validate.config[category] = @edit[:new][category].dup
      end
      if @validate.ldap_verify
        add_flash(I18n.t("flash.ops.settings.ldap_settings_validated"))
      else
        @validate.errors.each do |field,msg|
          add_flash("#{field.titleize}: #{msg}", :error)
        end
      end
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    elsif params[:button] == "amazon_verify"                                      # User doing amazon verify
      settings_get_form_vars
      return unless @edit
      @validate = MiqServer.find(@sb[:selected_server_id]).get_config("vmdb")
      @validate.config.each_key do |category|
        @validate.config[category] = @edit[:new][category].dup
      end
      if @validate.amazon_verify
        add_flash(I18n.t("flash.ops.settings.amazon_settings_validated"))
      else
        @validate.errors.each do |field,msg|
          add_flash("#{field.titleize}: #{msg}", :error)
        end
      end
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    elsif params[:button] == "email_verify"                                     # User doing ldap verify
      settings_get_form_vars
      return unless @edit
      begin
        GenericMailer.test_email(@sb[:new_to],@edit[:new][:smtp]).deliver
      rescue Exception => err
        add_flash(I18n.t("flash.ops.settings.error_during_email") << err.class.name << ", " << err.to_s, :error)
      else
        add_flash(I18n.t("flash.ops.settings.test_email_sent", :email=>@sb[:new_to]))
      end
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    elsif params[:button] == "db_verify"
      settings_get_form_vars
      return unless @edit
      db_config = MiqDbConfig.new(@edit[:new])
      result = db_config.valid?
      if result == true
        add_flash(I18n.t("flash.ops.settings.db_settings_validated"))
      else
        db_config.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
      end
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    elsif params[:button] == "save"
      settings_get_form_vars
      return unless @edit
      case @sb[:active_tab]
      when 'settings_rhn_edit'
        if rhn_allow_save?
          rhn_save_subscription
          add_flash(I18n.t("flash.ops.settings.customer_info_saved"))
          @changed = false
          @edit    = nil
          @sb[:active_tab] = 'settings_rhn'
          settings_get_info('root')
          replace_right_cell('root')
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
        @changed = (@edit[:new] != @edit[:current].config)
        @update = MiqServer.find(@sb[:selected_server_id]).get_config("vmdb")
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

        wb[:replication_worker][:replication][:destination].delete(:verify)
        @edit[:new].set_worker_setting!(:MiqReplicationWorker,:replication, wb[:replication_worker][:replication])

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

        @update = MiqServer.find(@sb[:selected_server_id]).get_config
      when "settings_database"                                      # Database tab
        db_config = MiqDbConfig.new(@edit[:new])
        result = db_config.save
        if result == true
          add_flash(I18n.t("flash.ops.settings.db_settings_saved"))
          @changed = false
          begin
            MiqServer.my_server(true).restart_queue
          rescue StandardError => bang
            add_flash(I18n.t("flash.ops.settings.error_during_task", :task=>"Server restart") << bang.message, :error)  # Push msg and error flag
          else
            add_flash(I18n.t("flash.record.task_initiated", :model=>ui_lookup(:table=>"evm_server"), :task=>"Restart"))
          end
        else
          db_config.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @changed = (@edit[:new] != @edit[:current])
        end
      when "settings_host"                                      # Host Settings tab
        @changed = (@edit[:new] != @edit[:current].config)
        @update = VMDB::Config.new("hostdefaults")            # Get the settings object to update it
      when "settings_custom_logos"                                      # Custom Logo tab
        @changed = (@edit[:new] != @edit[:current].config)
        @update = VMDB::Config.new("vmdb")                    # Get the settings object to update it
      when "settings_maintenance"                                         # Maintenance tab
      when "settings_smartproxy"                                          # SmartProxy Defaults tab
        @changed = (@edit[:new] != @edit[:current].config)
        @update = VMDB::Config.new("hostdefaults")            # Get the settings object to update it
        @update.config.each_key do |category|
          @update.config[category] = @edit[:new][category].dup
        end
        if @edit[:new][:agent][:wsListenPort] &&  !(@edit[:new][:agent][:wsListenPort] =~ /^\d+$/)
          add_flash(I18n.t("flash.edit.field_must_be.numeric", :field=>"Web Services Listen Port"), :error)
        end
        if @edit[:new][:agent][:log][:wrap_size] && (!(@edit[:new][:agent][:log][:wrap_size] =~ /^\d+$/) || @edit[:new][:agent][:log][:wrap_size].to_i == 0)
          add_flash(I18n.t("flash.edit.field_must_be.numeric_greater_than_0", :field=>"Log Wrap Size"), :error)
        end
        if ! @flash_array
          @update.config[:agent][:log][:wrap_size] = @edit[:new][:agent][:log][:wrap_size].to_i * 1024 * 1024
          if @update.validate       # Have VMDB class validate the settings
            @update.save
            add_flash(I18n.t("flash.ops.settings.smartproxy_settings_saved"))
            @changed = false
          else
            @update.errors.each do |field,msg|
              add_flash("#{field.titleize}: #{msg}", :error)
              @changed = true
            end
          end
        end
        get_node_info(x_node)
        replace_right_cell(@nodetype)
        return
      when "settings_advanced"                                          # Advanced manual yaml editor tab
        result = VMDB::Config.save_file(session[:config_file_name], @edit[:new][:file_data])  # Save the config file
        if result != true                                         # Result contains errors?
          result.each do |field,msg|
            add_flash("#{field.to_s.titleize}: #{msg}", :error)
          end
          @changed = (@edit[:new] != @edit[:current])
        else
          add_flash(I18n.t("flash.ops.settings.advanced_settings_saved", :filename=>VMDB::Config.available_config_names[session[:config_file_name]]))
          @changed = false
        end
#       redirect_to :action => 'explorer', :flash_msg=>msg, :flash_error=>err, :no_refresh=>true
        get_node_info(x_node)
        replace_right_cell(@nodetype)
        return
      end
      if !['settings_rhn_edit',"settings_workers","settings_database","settings_maintenance","settings_advanced"].include?(@sb[:active_tab]) &&
          x_node.split("-").first != "z"
        @update.config.each_key do |category|
          @update.config[category] = @edit[:new][category].dup
        end
        if @edit[:new][:ntp]
          @update.config[:ntp] = @edit[:new][:ntp].dup
        end
        if @update.validate                                           # Have VMDB class validate the settings
          if ["settings_server","settings_authentication"].include?(@sb[:active_tab])
            server = MiqServer.find(@sb[:selected_server_id])
            @validate = server.set_config(@update)  # Save server settings against selected server
          else
            @update.save                                              # Save other settings for current server
          end
          AuditEvent.success(build_config_audit(@edit[:new], @edit[:current].config))
          if @sb[:active_tab] == "settings_server"
            add_flash(I18n.t("flash.ops.settings.settings_saved", :typ=>"Configuration", :name=>server.name, :server_id=>server.id, :zone=>server.my_zone))
          elsif @sb[:active_tab] == "settings_authentication"
            add_flash(I18n.t("flash.ops.settings.settings_saved", :typ=>"Authentication", :name=>server.name, :server_id=>server.id, :zone=>server.my_zone))
          else
            add_flash(I18n.t("flash.ops.settings.config_settings_saved"))
          end
          if @sb[:active_tab] == "settings_server" && @sb[:selected_server_id] == MiqServer.my_server.id  # Reset session variables for names fields, if editing current server config
            session[:customer_name] = @update.config[:server][:company]
            session[:vmdb_name] = @update.config[:server][:name]
          elsif @sb[:active_tab] == "settings_custom_logos"                           # Reset session variable for logo field
            session[:custom_logo] = @update.config[:server][:custom_logo]
          end
          set_user_time_zone if @sb[:active_tab] == "settings_server"
          #settings_set_form_vars
          session[:changed] = @changed = false
          get_node_info(x_node)
          if @sb[:active_tab] == "settings_server"
            replace_right_cell(@nodetype,[:settings])
          elsif @sb[:active_tab] == "settings_custom_logos"
            render :update do |page|
              page.redirect_to :action => 'explorer', :flash_msg=>@flash_array[0][:message], :flash_error =>@flash_array[0][:level] == :error, :escape => false  # redirect to build the server screen
            end
            return
          else
            replace_right_cell(@nodetype)
          end
        else
          @update.errors.each do |field,msg|
            add_flash("#{field.titleize}: #{msg}", :error)
          end
          @changed = true
          session[:changed] = @changed
          get_node_info(x_node)
          replace_right_cell(@nodetype)
        end
      elsif @sb[:active_tab] == "settings_workers" &&
          x_node.split("-").first != "z"
        if !@edit[:default_verify_status]
          add_flash(I18n.t("flash.edit.passwords_mismatch"), :error)
        end
        if @flash_array != nil
          session[:changed] = @changed = true
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
          return
        end
        @update.config.each_key do |category|
          @update.config[category] = @edit[:new].config[category].dup
        end
        if @update.validate                                           # Have VMDB class validate the settings
          server = MiqServer.find(@sb[:selected_server_id])
          @validate = server.set_config(@update)  # Save server settings against selected server

          AuditEvent.success(build_config_audit(@edit[:new].config, @edit[:current].config))
          add_flash(I18n.t("flash.ops.settings.settings_saved", :typ=>"Configuration", :name=>server.name, :server_id=>@sb[:selected_server_id], :zone=>server.my_zone))

          if @sb[:active_tab] == "settings_workers" &&  @sb[:selected_server_id] == MiqServer.my_server.id  # Reset session variables for names fields, if editing current server config
            session[:customer_name] = @update.config[:server][:company]
            session[:vmdb_name] = @update.config[:server][:name]
          end
          @changed = false
          get_node_info(x_node)
          replace_right_cell(@nodetype)
        else
          @update.errors.each do |field,msg|
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
    elsif params[:button] == "reset"
      session[:changed] = @changed = false
      add_flash(I18n.t("flash.edit.reset"), :warning)
      if @sb[:active_tab] == 'settings_rhn_edit'
        edit_rhn
      else
        get_node_info(x_node)
        replace_right_cell(@nodetype)
      end
    elsif params[:button] == "cancel"
      @sb[:active_tab] = 'settings_rhn'
      @changed = false
      @edit = nil
      settings_get_info('root')
      add_flash(I18n.t('flash.ops.settings.customer_info_edit_cancelled'))
      replace_right_cell('root')
    end
  end

  def smartproxy_affinity_field_changed
    settings_load_edit
    return unless @edit

    smartproxy_affinity_get_form_vars(params[:id], params[:check] == '1') if params[:id] && params[:check]

    changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  private

  def settings_server_validate
    if @sb[:active_tab] == "settings_server" && @edit[:new][:server] && ((@edit[:new][:server][:custom_support_url].nil? || @edit[:new][:server][:custom_support_url].strip == "") && (!@edit[:new][:server][:custom_support_url_description].nil? && @edit[:new][:server][:custom_support_url_description].strip != "") ||
        (@edit[:new][:server][:custom_support_url_description].nil? || @edit[:new][:server][:custom_support_url_description].strip == "") && (!@edit[:new][:server][:custom_support_url].nil? && @edit[:new][:server][:custom_support_url].strip != ""))
      add_flash(I18n.t("flash.ops.settings.custom_url_and_description_required"), :error)
    end
    if @sb[:active_tab] == "settings_server" && @edit[:new].fetch_path(:server, :remote_console_type) == "VNC"
      unless @edit[:new][:server][:vnc_proxy_port] =~ /^\d+$/ || @edit[:new][:server][:vnc_proxy_port].blank?
        add_flash(I18n.t("flash.edit.field_must_be.numeric", :field=>"VNC Proxy Port"), :error)
      end
      unless (@edit[:new][:server][:vnc_proxy_address].blank? &&
          @edit[:new][:server][:vnc_proxy_port].blank?) ||
          (!@edit[:new][:server][:vnc_proxy_address].blank? &&
              !@edit[:new][:server][:vnc_proxy_port].blank?)
        add_flash(I18n.t("flash.edit.vnc_proxy_fields_required"), :error)
      end
    end
  end

  def smartproxy_affinity_get_form_vars(id, checked)
    # Add/remove affinity based on the node that was checked
    server_id, child = id.split('__')

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
        server.each_value { |v| v.clear }
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

    @temp[:smartproxy_affinity_tree] = build_smartproxy_affinity_tree(@selected_zone)

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
    add_flash(I18n.t("flash.ops.settings.error_during_task",
                     :task => "Analysis Affinity save") << bang.message, :error)
  else
    add_flash(I18n.t("flash.ops.settings.analysis_affinity_saved"))
  end

  # load @edit from session and then update @edit from params based on active_tab
  def settings_get_form_vars
    settings_load_edit
    return unless @edit
    @in_a_form = true
    nodes = x_node.downcase.split("-")
    cls = nodes.first.split('__').last == "z" ? Zone : MiqServer
    # WTF? here we can have a Zone or a MiqServer, what about Region? --> rescue from exception
    @temp[:selected_server] = (cls.find(from_cid(nodes.last)) rescue nil)

    case @sb[:active_tab]                                               # No @edit[:current].config for Filters since there is no config file
    when 'settings_rhn_edit'
      for key in [:proxy_address, :use_proxy, :proxy_userid, :proxy_password, :proxy_verify,
                  :register_to, :server_url, :repo_name, :customer_org,
                  :customer_userid, :customer_password, :customer_verify]
        if params[key]
          @edit[:new][key] = params[key]
          @changed = true
        end
      end
    when "settings_server"                                                # Server Settings tab
      if !params[:smtp_test_to].nil? && params[:smtp_test_to] != ""
        @sb[:new_to] = params[:smtp_test_to]
      elsif params[:smtp_test_to] && (params[:smtp_test_to] == "" || params[:smtp_test_to].nil?)
        @sb[:new_to] = nil
      end
      @edit[:new][:smtp][:authentication] = params[:smtp_authentication] if params[:smtp_authentication]
      @smtp_auth_none = (@edit[:new][:smtp][:authentication] == "none")
      if !@edit[:new][:smtp][:host].blank? && !@edit[:new][:smtp][:port].blank? && !@edit[:new][:smtp][:domain].blank? &&
          (!@edit[:new][:smtp][:user_name].blank? || @edit[:new][:smtp][:authentication] == "none") &&
          !@edit[:new][:smtp][:from].blank? && !@sb[:new_to].blank?
        @test_email_button = true
      else
        @test_email_button = false
      end
      @sb[:roles] = @edit[:new][:server][:role].split(",")
      params.each do |var, val|
        if var.starts_with?("server_roles_") && val.to_s == "1"
          @sb[:roles].push(var.split("server_roles_").last) unless @sb[:roles].include?(var.split("server_roles_").last)
        elsif var.starts_with?("server_roles_") && val.downcase == "null"
          @sb[:roles].delete(var.split("server_roles_").last)
        end
        server_role = @sb[:roles].sort.join(",")
        @edit[:new][:server][:role] = server_role
        session[:selected_roles] = @edit[:new][:server][:role].split(",") if !@edit[:new][:server].nil? && !@edit[:new][:server][:role].nil?
      end
      @host_choices = session[:host_choices]
      @edit[:new][:server][:remote_console_type] = params[:console_type] if params[:console_type]

      @edit[:new][:ntp][:server] ||= Array.new
      @edit[:new][:ntp][:server][0] = params[:ntp_server_1] if params[:ntp_server_1]
      @edit[:new][:ntp][:server][1] = params[:ntp_server_2] if params[:ntp_server_2]
      @edit[:new][:ntp][:server][2] = params[:ntp_server_3] if params[:ntp_server_3]

      @edit[:new][:ntp][:server].each_with_index do |ntp,i|
        if @edit[:new][:ntp][:server][i].nil? || @edit[:new][:ntp][:server][i] == ""
          @edit[:new][:ntp][:server].delete_at(i)
        end
      end

      @edit[:new][:server][:custom_support_url] = params[:custom_support_url].strip if params[:custom_support_url]
      @edit[:new][:server][:custom_support_url_description] = params[:custom_support_url_description] if params[:custom_support_url_description]
    when "settings_authentication"                                        # Authentication/SmartProxy Affinity tab
      @sb[:form_vars][:session_timeout_mins] = params[:session_timeout_mins] if params[:session_timeout_mins]
      @sb[:form_vars][:session_timeout_hours] = params[:session_timeout_hours] if params[:session_timeout_hours]
      @edit[:new][:session][:timeout] = @sb[:form_vars][:session_timeout_hours].to_i * 3600 + @sb[:form_vars][:session_timeout_mins].to_i * 60 if params[:session_timeout_hours] || params[:session_timeout_mins]
      @sb[:newrole] = (params[:ldap_role].to_s == "1") if params[:ldap_role]
      @sb[:new_amazon_role] = (params[:amazon_role].to_s == "1") if params[:amazon_role]
      @sb[:new_httpd_role] = (params[:httpd_role].to_s == "1") if params[:httpd_role]
      if params[:authentication_user_type] && params[:authentication_user_type] != @edit[:new][:authentication][:user_type]
        @authusertype_changed = true
      end
      @edit[:new][:authentication][:user_suffix] = params[:authentication_user_suffix] if params[:authentication_user_suffix]
      if @sb[:newrole] != @edit[:new][:authentication][:ldap_role]
        @edit[:new][:authentication][:ldap_role] = @sb[:newrole]
        @authldaprole_changed = true
      end
      if @sb[:new_amazon_role] != @edit[:new][:authentication][:amazon_role]
        @edit[:new][:authentication][:amazon_role] = @sb[:new_amazon_role]
      end
      if @sb[:new_httpd_role] != @edit[:new][:authentication][:httpd_role]
        @edit[:new][:authentication][:httpd_role] = @sb[:new_httpd_role]
      end
      if params[:authentication_mode] && params[:authentication_mode] != @edit[:new][:authentication][:mode]
        if params[:authentication_mode] == "ldap"
          params[:authentication_ldapport] = "389"
          @authldapport_reset = true
        elsif params[:authentication_mode] == "ldaps"
          params[:authentication_ldapport] = "636"
          @authldapport_reset = true
        else
          @sb[:newrole] = @edit[:new][:authentication][:ldap_role] = false    # setting it to false if database was selected to hide user_proxies box
        end
        @authmode_changed = true
      end
      if (params[:authentication_ldaphost_1] || params[:authentication_ldaphost_2] || params[:authentication_ldaphost_3]) ||
          (params[:authentication_ldapport] != @edit[:new][:authentication][:ldapport])
        @reset_verify_button = true
      end
      if (params[:authentication_amazon_key] != @edit[:new][:authentication][:amazon_key]) ||
          (params[:authentication_amazon_secret] != @edit[:new][:authentication][:amazon_secret])
        @reset_amazon_verify_button = true
      end

      @edit[:new][:authentication][:amazon_key] = params[:authentication_amazon_key] if params[:authentication_amazon_key]
      @edit[:new][:authentication][:amazon_secret] = params[:authentication_amazon_secret] if params[:authentication_amazon_secret]
      @edit[:new][:authentication][:ldaphost] ||= Array.new
      @edit[:new][:authentication][:ldaphost][0] = params[:authentication_ldaphost_1] if params[:authentication_ldaphost_1]
      @edit[:new][:authentication][:ldaphost][1] = params[:authentication_ldaphost_2] if params[:authentication_ldaphost_2]
      @edit[:new][:authentication][:ldaphost][2] = params[:authentication_ldaphost_3] if params[:authentication_ldaphost_3]

      @edit[:new][:authentication][:ldaphost].each_with_index do |ntp,i|
        if @edit[:new][:authentication][:ldaphost][i].nil? || @edit[:new][:authentication][:ldaphost][i] == ""
          @edit[:new][:authentication][:ldaphost].delete_at(i)
        end
      end

      @edit[:new][:authentication][:follow_referrals] = (params[:follow_referrals].to_s == "1") if params[:follow_referrals]
      @edit[:new][:authentication][:get_direct_groups] = (params[:get_direct_groups].to_s == "1") if params[:get_direct_groups]
      if params[:user_proxies] && params[:user_proxies][:mode] != @edit[:new][:authentication][:user_proxies][0][:mode]
        if params[:user_proxies][:mode] == "ldap"
          params[:user_proxies][:ldapport] = "389"
          @user_proxies_port_reset = true
        elsif params[:user_proxies][:mode] == "ldaps"
          params[:user_proxies][:ldapport] = "636"
          @user_proxies_port_reset = true
        end
        @authmode_changed = true
      end
    when "settings_workers"                                       # Workers Settings tab
      wb  = @edit[:new].config[:workers][:worker_base]
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

      w = wb[:replication_worker][:replication][:destination]
      w[:database] = params[:replication_worker_dbname] if params[:replication_worker_dbname]
      w[:port] = params[:replication_worker_port] if params[:replication_worker_port]
      w[:username] = params[:replication_worker_username] if params[:replication_worker_username]
      w[:password] = params[:replication_worker_password] if params[:replication_worker_password]
      w[:verify] = params[:replication_worker_verify] if params[:replication_worker_verify]
      w[:host] = params[:replication_worker_host] if params[:replication_worker_host]

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

      set_workers_verify_status
    when "settings_database"                                        # database tab
      @edit[:new][:name] = params[:production_dbtype]  if params[:production_dbtype]
      @options = MiqDbConfig.get_db_type_options(@edit[:new][:name])
      @options.each do |option|
        @edit[:new][option[:name]] = params["production_#{option[:name]}".to_sym]  if params["production_#{option[:name]}".to_sym]
      end
      @edit[:new][:verify] = params[:production_verify]  if params[:production_verify]
    when "settings_host"                                        # Smart Hosts tab
      if params[:host_autoscan]
        @edit[:new][:host][:autoscan] = params[:host_autoscan] == "1" ? true : nil
      end
      if params[:host_inherit_mgt_tags]
        @edit[:new][:host][:inherit_mgt_tags] = params[:host_inherit_mgt_tags] == "1" ? true : nil
      end
      #@edit[:new][:host][:scan_frequency] = params[:host_scan_frequency][:days] .to_i * 3600 * 24 if params[:host_scan_frequency]
    when "settings_custom_logos"                                            # Custom Logo tab
      @edit[:new][:server][:custom_logo] = (params[:server_uselogo] == "1") if params[:server_uselogo]
      @edit[:new][:server][:custom_login_logo] = (params[:server_useloginlogo] == "1") if params[:server_useloginlogo]
      @edit[:new][:server][:use_custom_login_text] = (params[:server_uselogintext] == "1") if params[:server_uselogintext]
      if params[:login_text]
        @edit[:new][:server][:custom_login_text] = params[:login_text]
        @login_text_changed = @edit[:new][:server][:custom_login_text] != @edit[:current].config[:server][:custom_login_text].to_s
      end
    when "settings_maintenance"                                       # Maintenance tab
    when "settings_smartproxy"                                        # SmartProxy Defaults tab
      #@edit = session[:edit]
      @sb[:form_vars][:agent_heartbeat_frequency_mins] = params[:agent_heartbeat_frequency_mins] if params[:agent_heartbeat_frequency_mins]
      @sb[:form_vars][:agent_heartbeat_frequency_secs] = params[:agent_heartbeat_frequency_secs] if params[:agent_heartbeat_frequency_secs]
      @sb[:form_vars][:agent_log_wraptime_days] = params[:agent_log_wraptime_days] if params[:agent_log_wraptime_days]
      @sb[:form_vars][:agent_log_wraptime_hours] = params[:agent_log_wraptime_hours] if params[:agent_log_wraptime_hours]
      @edit[:new][:agent][:heartbeat_frequency] = @sb[:form_vars][:agent_heartbeat_frequency_mins].to_i * 60 + @sb[:form_vars][:agent_heartbeat_frequency_secs].to_i if params[:agent_heartbeat_frequency_mins] || params[:agent_heartbeat_frequency_secs]
      @edit[:new][:agent][:log][:level] = params[:agent_log_level] if params[:agent_log_level]
      @edit[:new][:agent][:log][:wrap_size] = params[:agent_log_wrapsize] if params[:agent_log_wrapsize]
      @edit[:new][:agent][:log][:wrap_time] = @sb[:form_vars][:agent_log_wraptime_days].to_i * 3600 * 24 + @sb[:form_vars][:agent_log_wraptime_hours].to_i * 3600 if params[:agent_log_wraptime_days] || params[:agent_log_wraptime_hours]
      @edit[:new][:agent][:readonly] = (params[:agent_readonly] == "1") if params[:agent_readonly]
    when "settings_advanced"                                        # Advanced tab
      if params[:file_name] && params[:file_name] != session[:config_file_name] # If new file name was selected
        session[:config_file_name] = params[:file_name]
        settings_set_form_vars
      elsif params[:file_data]                        # If save sent in the file data
        @edit[:new][:file_data] = params[:file_data]  # Put into @edit[:new] hash
      else
        @edit[:new][:file_data] += "..."              # Update the new data to simulate a change
      end
    end

    # This section scoops up the config second level keys changed in the UI
    if !['settings_rhn_edit',"settings_database","settings_maintenance","settings_advanced","settings_smartproxy_affinity"].include?(@sb[:active_tab])
      @edit[:current].config.each_key do |category|
        @edit[:current].config[category].symbolize_keys.each_key do |key|
          if category == :smtp && key == :enable_starttls_auto  # Checkbox is handled differently
            @edit[:new][category][key] = params["#{category}_#{key}"] == "1" if params.has_key?("#{category}_#{key}")
          else
            @edit[:new][category][key] = params["#{category}_#{key}"] if params["#{category}_#{key}"]
          end
        end
        @edit[:new][:authentication][:user_proxies][0] = copy_hash(params[:user_proxies]) if params[:user_proxies] && category == :authentication
      end
    end
  end

  # Load the @edit object from session based on which config screen we are on
  def settings_load_edit
    if x_node.split("-").first == "z"
      #if zone node is selected
      return unless load_edit("#{@sb[:active_tab]}_edit__#{@sb[:selected_zone_id]}","replace_cell__explorer")
      @prev_selected_svr = session[:edit][:new][:selected_server]
    elsif @sb[:active_tab] == 'settings_rhn_edit'
      @edit = session[:edit]
    else
      if ["settings_server","settings_authentication","settings_workers",
              "settings_database","settings_host","settings_custom_logos",
              "settings_smartproxy","settings_advanced"].include?(@sb[:active_tab])
        return unless load_edit("settings_#{params[:id]}_edit__#{@sb[:selected_server_id]}","replace_cell__explorer")
      end
    end
  end

  def settings_set_form_vars
    if x_node.split("-").first == "z"
      @right_cell_text = @sb[:my_zone] == @selected_zone.name ?
        I18n.t("cell_header.type_of_model_record_current",:typ=>"Settings",:name=>@selected_zone.description,:model=>ui_lookup(:model=>@selected_zone.class.to_s)) :
        I18n.t("cell_header.type_of_model_record",:typ=>"Settings",:name=>@selected_zone.description,:model=>ui_lookup(:model=>@selected_zone.class.to_s))
    else
      @right_cell_text = @sb[:my_server_id] == @sb[:selected_server_id] ?
        I18n.t("cell_header.type_of_model_record_current",:typ=>"Settings",:name=>"#{@temp[:selected_server].name} [#{@temp[:selected_server].id.to_s}]",:model=>ui_lookup(:model=>@temp[:selected_server].class.to_s)) :
        I18n.t("cell_header.type_of_model_record",:typ=>"Settings",:name=>"#{@temp[:selected_server].name} [#{@temp[:selected_server].id.to_s}]",:model=>ui_lookup(:model=>@temp[:selected_server].class.to_s))
    end
    case @sb[:active_tab]
    when "settings_server"                                  # Server Settings tab
      @edit = Hash.new
      @edit[:new] = Hash.new
      @edit[:current] = Hash.new
      @edit[:current] = MiqServer.find(@sb[:selected_server_id]).get_config("vmdb")
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @sb[:new_to] = nil
      @sb[:newrole] = false
      session[:server_zones] = Array.new
      zones = Zone.all
      zones.each do |zone|
        session[:server_zones].push(zone.name)
      end
      @edit[:current].config[:server][:role] = @edit[:current].config[:server][:role] ? @edit[:current].config[:server][:role].split(",").sort.join(",") : ""
      @edit[:current].config[:server][:timezone] = "UTC" if @edit[:current].config[:server][:timezone].blank?
      @edit[:current].config[:server][:remote_console_type] ||= "MKS"
      @edit[:current].config[:server][:vnc_proxy_address] ||= nil
      @edit[:current].config[:server][:vnc_proxy_port] ||= nil
      @edit[:current].config[:smtp][:enable_starttls_auto] = GenericMailer.default_for_enable_starttls_auto if @edit[:current].config[:smtp][:enable_starttls_auto].nil?
      @edit[:current].config[:smtp][:openssl_verify_mode] ||= nil
      @edit[:current].config[:ntp] ||= Hash.new
      @edit[:current].config[:ntp][:server] ||= Array.new
      get_smartproxy_choices
      @in_a_form = true
    when "settings_authentication"        # Authentication tab
      @edit = Hash.new
      @edit[:new] = Hash.new
      @edit[:current] = Hash.new
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @edit[:current] = MiqServer.find(@sb[:selected_server_id]).get_config("vmdb")
      # Avoid thinking roles change when not yet set
      @edit[:current].config[:authentication][:ldap_role]   ||= false
      @edit[:current].config[:authentication][:amazon_role] ||= false
      @edit[:current].config[:authentication][:httpd_role]  ||= false
      @sb[:form_vars] = Hash.new
      @sb[:form_vars][:session_timeout_hours] = @edit[:current].config[:session][:timeout]/3600
      @sb[:form_vars][:session_timeout_mins] = (@edit[:current].config[:session][:timeout]%3600)/60
      @edit[:current].config[:authentication][:ldaphost] = @edit[:current].config[:authentication][:ldaphost].to_miq_a
      @edit[:current].config[:authentication][:user_proxies] ||= [{}]
      @edit[:current].config[:authentication][:follow_referrals] ||= false
      @sb[:newrole] = @edit[:current].config[:authentication][:ldap_role]
      @sb[:new_amazon_role] = @edit[:current].config[:authentication][:amazon_role]
      @sb[:new_httpd_role] = @edit[:current].config[:authentication][:httpd_role]
      @in_a_form = true
    when "settings_smartproxy_affinity"                                 #SmartProxy Affinity tab
      smartproxy_affinity_set_form_vars
    when "settings_workers"                                 # Worker Settings tab
      # getting value in "1.megabytes" bytes from backend, converting it into "1 MB" to display in UI, and then later convert it into "1.megabytes" to before saving it back into config.
      # need to create two copies of config new/current set_worker_setting! is a instance method, need @edit[:new] to be config class to set count/memory_threshold, can't run method against hash
      @edit = Hash.new
      @edit[:new] = Hash.new
      @edit[:current] = Hash.new
      @edit[:current] = MiqServer.find(@sb[:selected_server_id]).get_config
      @edit[:new] = MiqServer.find(@sb[:selected_server_id]).get_config
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @sb[:threshold] = Array.new
      (200.megabytes...550.megabytes).step(50.megabytes) {|x| @sb[:threshold] << number_to_human_size(x, :significant=>false)}
      (600.megabytes...1000.megabytes).step(100.megabytes) {|x| @sb[:threshold] << number_to_human_size(x, :significant=>false)}    # adding values in 100 MB increments from 600 to 1gb, dividing in two statements else it puts 1000MB instead of 1GB in pulldown
      (1.gigabytes...1.5.gigabytes).step(100.megabytes) {|x| @sb[:threshold] << number_to_human_size(x, :significant=>false)}   # adding values in 100 MB increments from 1gb to 1.5 gb

      cwb = @edit[:current].config[:workers][:worker_base] ||= Hash.new
      qwb = (cwb[:queue_worker_base] ||= Hash.new)
      w = (qwb[:generic_worker] ||= Hash.new)
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqGenericWorker, :count) || 2
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqGenericWorker, :memory_threshold)) || rails_method_to_human_size(400.megabytes)
      @sb[:generic_threshold] = Array.new
      @sb[:generic_threshold] = copy_array(@sb[:threshold])

      w = (qwb[:priority_worker] ||= Hash.new)
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqPriorityWorker, :count) || 2
      w[:memory_threshold] =  rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqPriorityWorker, :memory_threshold)) || rails_method_to_human_size(200.megabytes)
      @sb[:priority_threshold] = Array.new
      @sb[:priority_threshold] = copy_array(@sb[:threshold])

      qwb[:ems_metrics_collector_worker]            ||= Hash.new
      qwb[:ems_metrics_collector_worker][:defaults] ||= Hash.new
      w = qwb[:ems_metrics_collector_worker][:defaults]
      raw = @edit[:current].get_raw_worker_setting(:MiqEmsMetricsCollectorWorker)
      w[:count] = raw[:defaults][:count] || 2
      w[:memory_threshold] = rails_method_to_human_size(raw[:defaults][:memory_threshold] || 400.megabytes)
      @sb[:ems_metrics_collector_threshold] = Array.new
      @sb[:ems_metrics_collector_threshold] = copy_array(@sb[:threshold])

      w = (qwb[:ems_metrics_processor_worker] ||= Hash.new)
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqEmsMetricsProcessorWorker, :count) || 2
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqEmsMetricsProcessorWorker, :memory_threshold)) || rails_method_to_human_size(200.megabytes)
      @sb[:ems_metrics_processor_threshold] = Array.new
      @sb[:ems_metrics_processor_threshold] = copy_array(@sb[:threshold])

      w = (qwb[:smart_proxy_worker] ||= Hash.new)
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqSmartProxyWorker, :count) || 3
      w[:memory_threshold] =  rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqSmartProxyWorker, :memory_threshold)) || rails_method_to_human_size(400.megabytes)
      @sb[:smart_proxy_threshold] = Array.new
      @sb[:smart_proxy_threshold] = copy_array(@sb[:threshold])

      qwb[:ems_refresh_worker]            ||= Hash.new
      qwb[:ems_refresh_worker][:defaults] ||= Hash.new
      w = qwb[:ems_refresh_worker][:defaults]
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqEmsRefreshWorker, [:defaults, :memory_threshold])) || rails_method_to_human_size(400.megabytes)
      @sb[:ems_refresh_threshold] = Array.new
      (200.megabytes...550.megabytes).step(50.megabytes) {|x| @sb[:ems_refresh_threshold] << number_to_human_size(x, :significant=>false)}
      (600.megabytes..900.megabytes).step(100.megabytes) {|x| @sb[:ems_refresh_threshold] << number_to_human_size(x, :significant=>false)}
      (1.gigabytes..2.9.gigabytes).step(1.gigabyte/10) {|x| @sb[:ems_refresh_threshold] << number_to_human_size(x, :significant=>false)}
      (3.gigabytes..10.gigabytes).step(512.megabytes) {|x| @sb[:ems_refresh_threshold] << number_to_human_size(x, :significant=>false)}

      wb = @edit[:current].config[:workers][:worker_base]
      w = (wb[:event_catcher] ||= Hash.new)
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqEventCatcher, :memory_threshold)) || rails_method_to_human_size(1.gigabytes)
      @sb[:event_catcher_threshold] = Array.new
      (500.megabytes...1000.megabytes).step(100.megabytes) {|x| @sb[:event_catcher_threshold] << number_to_human_size(x, :significant=>false)}
      (1.gigabytes..2.9.gigabytes).step(1.gigabyte/10) {|x| @sb[:event_catcher_threshold] << number_to_human_size(x, :significant=>false)}
      (3.gigabytes..10.gigabytes).step(512.megabytes) {|x| @sb[:event_catcher_threshold] << number_to_human_size(x, :significant=>false)}

      w = (wb[:vim_broker_worker] ||= Hash.new)
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqVimBrokerWorker, :memory_threshold)) || rails_method_to_human_size(1.gigabytes)
      @sb[:vim_broker_threshold] = Array.new
      (500.megabytes..900.megabytes).step(100.megabytes) {|x| @sb[:vim_broker_threshold] << number_to_human_size(x, :significant=>false)}
      (1.gigabytes..2.9.gigabytes).step(1.gigabyte/10) {|x| @sb[:vim_broker_threshold] << number_to_human_size(x, :significant=>false)}
      (3.gigabytes..10.gigabytes).step(512.megabytes) {|x| @sb[:vim_broker_threshold] << number_to_human_size(x, :significant=>false)}

      w = (wb[:ui_worker] ||= Hash.new)
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqUiWorker, :count) || 2

      rw = (wb[:replication_worker] ||= Hash.new)
      r = (rw[:replication] ||= Hash.new)
      d = (r[:destination] ||= Hash.new)
      d[:verify] = d[:password]

      w = (qwb[:reporting_worker] ||= Hash.new)
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqReportingWorker, :count) || 2
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqReportingWorker, :memory_threshold)) || rails_method_to_human_size(400.megabytes)
      @sb[:reporting_threshold] = Array.new
      @sb[:reporting_threshold] = copy_array(@sb[:threshold])

      w = (wb[:web_service_worker] ||= Hash.new)
      w[:count] = @edit[:current].get_raw_worker_setting(:MiqWebServiceWorker, :count) || 2
      w[:memory_threshold] = rails_method_to_human_size(@edit[:current].get_raw_worker_setting(:MiqWebServiceWorker, :memory_threshold)) || rails_method_to_human_size(400.megabytes)
      @sb[:web_service_threshold] = Array.new
      @sb[:web_service_threshold] = copy_array(@sb[:threshold])

      @edit[:new].config = copy_hash(@edit[:current].config)
      session[:log_depot_default_verify_status] = true
      set_workers_verify_status
      @in_a_form = true
    when "settings_database"                                  # Database tab
      @edit = Hash.new
      @edit[:new] = Hash.new
      @edit[:current] = Hash.new
      @edit[:current] = MiqDbConfig.current.options
      @edit[:current][:verify] = @edit[:current][:password] if @edit[:current][:password]
      @edit[:new] = copy_hash(@edit[:current])
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @options = MiqDbConfig.get_db_type_options(@edit[:new][:name])
      @in_a_form = true
    when "settings_host"                                    # Host Settings tab
      @edit = Hash.new
      @edit[:new] = Hash.new
      @edit[:current] = Hash.new
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @edit[:current] = VMDB::Config.new("hostdefaults")        # Get the host default settings
      @in_a_form = true
    when "settings_custom_logos"                                  # Custom Logo tab
      @edit = Hash.new
      @edit[:new] = Hash.new
      @edit[:current] = Hash.new
      @edit[:current] = VMDB::Config.new("vmdb")                # Get the vmdb configuration settings
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      if @edit[:current].config[:server][:custom_logo] == nil
        @edit[:current].config[:server][:custom_logo] = false # Set default custom_logo flag
      end
      @logo_file = @@logo_file
      @login_logo_file = @@login_logo_file
      @in_a_form = true
    when "settings_maintenance"                                 # Maintenance tab
      init_server_options
      @server_options[:server_id] = MiqServer.my_server.id
      @server_options[:version] = MiqServer.my_server.version
      @server_options[:name] = MiqServer.my_server.name
      @server_options[:remote] = false
      product_updates_list
    when "settings_smartproxy"                                    # SmartProxy Defaults tab
      @edit = Hash.new
      @edit[:new] = Hash.new
      @edit[:current] = Hash.new
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @edit[:current] = VMDB::Config.new("hostdefaults")        # Get the host default settings
      @edit[:current].config[:agent][:log][:wrap_size] = (@edit[:current].config[:agent][:log][:wrap_size].to_i / 1024 / 1024).to_s
      @edit[:current].config.each_key do |category|
        @edit[:new][category] = copy_hash(@edit[:current].config[category])
      end
      @sb[:form_vars] = Hash.new
      @sb[:form_vars][:agent_heartbeat_frequency_mins] = @edit[:new][:agent][:heartbeat_frequency]/60
      @sb[:form_vars][:agent_heartbeat_frequency_secs] = @edit[:new][:agent][:heartbeat_frequency]%60
      @sb[:form_vars][:agent_log_wraptime_days] = @edit[:new][:agent][:log][:wrap_time]/24/3600
      @sb[:form_vars][:agent_log_wraptime_hours] = @edit[:new][:agent][:log][:wrap_time]%(24*3600)/3600
      session[:edit] = @edit
      @in_a_form = true
    when "settings_advanced"                                  # Advanced yaml editor
      session[:config_file_name] ||= VMDB::Config.available_config_names.invert.sort.first.last # Start with first config file name
      @edit = Hash.new
      @edit[:current]={:file_data=>VMDB::Config.get_file(session[:config_file_name])}
      @edit[:new] = copy_hash(@edit[:current])
      @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
      @in_a_form = true
    end
    if ["settings_server","settings_authentication","settings_custom_logos","settings_smartproxy","settings_host"].include?(@sb[:active_tab]) &&
        x_node.split("-").first != "z"
      @edit[:current].config.each_key do |category|
        @edit[:new][category] = copy_hash(@edit[:current].config[category])
      end
      if @sb[:active_tab] == "settings_server"
        session[:selected_roles] = @edit[:new][:server][:role].split(",") if !@edit[:new][:server].nil? && !@edit[:new][:server][:role].nil?
        server_roles = MiqServer.licensed_roles           # Get the roles this server is licensed for
        server_roles.delete_if{|r|r.name == "database_owner"}
        session[:server_roles] = Hash.new
        server_roles.each do |sr|
          session[:server_roles][sr["name"]] = sr["description"] unless session[:server_roles].has_key?(sr["name"])
        end
      end
    end
    session[:edit] = @edit
  end

  # Get information for a settings node
  def settings_get_info(nodetype)
    nodes = nodetype.downcase.split("-")
    case nodes[0]
      when "root"
        @right_cell_text = I18n.t("cell_header.type_of_model_record",:typ=>"Settings",:name=>"#{MiqRegion.my_region.description} [#{MiqRegion.my_region.region}]",:model=>ui_lookup(:model=>"MiqRegion"))
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
          cats = Classification.categories.sort{|a,b| a.description <=> b.description}  # Get the categories, sort by name
          @cats = Hash.new                                        # Classifications array for first chooser
          cats.each do |c|
            @cats[c.description] = c.name if !c.read_only?    # Show the non-read_only categories
          end
          @cat = cats.first
          ce_build_screen                                         # Build the Classification Edit screen
        when "settings_import_tags"
          @edit = Hash.new
          @edit[:new] = Hash.new
          @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
          add_flash(I18n.t("flash.browse_to_upload_import"))
          @in_a_form = true
        when "settings_import"                                  # Import tab
          @edit = Hash.new
          @edit[:new] = Hash.new
          @edit[:key] = "#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}"
          @edit[:new][:upload_type] = nil
          @sb[:good] = nil if !@sb[:show_button]
          add_flash(I18n.t("flash.ops.settings.custom_variable_type_to_import"))
          @in_a_form = true
        when "settings_rhn"
          @edit = session[:edit] || {}
          @edit[:new] ||= {}
          @edit[:new][:servers] ||= {}
          @customer = rhn_subscription
          @buttons_on = @edit[:new][:servers].detect {|_,value| !!value}
          @check_all  = @edit[:new][:servers_all]
          @updates = rhn_update_information
        end
      when "xx"
        case nodes[1]
          when "z"
            @right_cell_text = I18n.t("cell_header.type_of_model_records",:typ=>"Settings",:model=>ui_lookup(:models=>"Zone"))
            @zones = Zone.in_my_region.all
          when "sis"
            @right_cell_text = I18n.t("cell_header.type_of_model_records",:typ=>"Settings",:model=>ui_lookup(:models=>"ScanItemSet"))
            aps_list
          when "msc"
            @right_cell_text = I18n.t("cell_header.type_of_model_records",:typ=>"Settings",:model=>ui_lookup(:models=>"MiqSchedule"))
            schedules_list
          when "l"
            @right_cell_text = I18n.t("cell_header.type_of_model_records",:typ=>"Settings",:model=>ui_lookup(:models=>"LdapRegion"))
            ldap_regions_list
        end
      when "svr"
        #@sb[:tabform] = "operations_1" if @sb[:selected_server] && @sb[:selected_server].id != nodetype.downcase.split("-").last.to_i #reset tab if server node was changed, current server has 10 tabs, current active tab may not be available for other server nodes.
  #     @sb[:selected_server] = MiqServer.find(from_cid(nodetype.downcase.split("-").last))
        @temp[:selected_server] = MiqServer.find(from_cid(nodes.last))
        @sb[:selected_server_id] = @temp[:selected_server].id
        settings_set_form_vars if params[:button] != "db_verify"
      when "msc"
        @record = @selected_schedule = MiqSchedule.find(from_cid(nodes.last))
        @right_cell_text = I18n.t("cell_header.type_of_model_record",:typ=>"Settings",:name=>@selected_schedule.name,:model=>ui_lookup(:model=>"MiqSchedule"))
        schedule_show
      when "ld","lr"
        nodes = nodetype.split('-')
        if nodes[0] == "lr"
          @record = @selected_lr = LdapRegion.find(from_cid(nodes[1]))
          @right_cell_text = I18n.t("cell_header.type_of_model_record",:typ=>"Settings",:name=>@selected_lr.name,:model=>ui_lookup(:model=>"LdapRegion"))
          ldap_region_show
        else
          @record = @selected_ld = LdapDomain.find(from_cid(nodes[1]))
          @right_cell_text = I18n.t("cell_header.type_of_model_record",:typ=>"Settings",:name=>@selected_ld.name,:model=>ui_lookup(:model=>"LdapDomain"))
          ldap_domain_show
        end
      when "sis"
        @record = @selected_scan = ScanItemSet.find(from_cid(nodes.last))
        @right_cell_text = I18n.t("cell_header.type_of_model_record",:typ=>"Settings",:name=>@selected_scan.name,:model=>ui_lookup(:model=>"ScanItemSet"))
        ap_show
      when "z"
        @servers = Array.new
        @record = @zone = @selected_zone = Zone.find(from_cid(nodes.last))
        @sb[:tab_label] = @selected_zone.description
        @right_cell_text = @sb[:my_zone] == @selected_zone.name ?
            I18n.t("cell_header.type_of_model_record_current",:typ=>"Settings",:name=>@selected_zone.description,:model=>ui_lookup(:model=>@selected_zone.class.to_s)) :
            I18n.t("cell_header.type_of_model_record",:typ=>"Settings",:name=>@selected_zone.description,:model=>ui_lookup(:model=>@selected_zone.class.to_s))
        MiqServer.all.each do |ms|
          if ms.zone_id == @selected_zone.id
            @servers.push(ms)
          end
        end
        smartproxy_affinity_set_form_vars if @sb[:active_tab] == "settings_smartproxy_affinity"
    end
  end

  #Build the main Settings tree
  def settings_build_tree
    TreeBuilderOpsSettings.new("settings_tree", "settings", @sb)
  end

  def settings_set_view_vars
    if @sb[:active_tab] == "settings_details"
      # Enterprise Details tab
      @temp[:scan_items] = ScanItemSet.all
      @temp[:zones] = Zone.in_my_region.all
      @temp[:ldap_regions] = LdapRegion.in_my_region.all
      @temp[:miq_schedules] = Array.new
      MiqSchedule.all(:conditions=>"prod_default != 'system' or prod_default is null").sort{
                          |a,b| a.name.downcase <=> b.name.downcase}.each do |z|
        if z.adhoc.nil? && (z.towhat != "DatabaseBackup" || (z.towhat == "DatabaseBackup" && DatabaseBackup.backup_supported?))
          @temp[:miq_schedules].push(z) unless @temp[:miq_schedules].include?(z)
        end
      end
#   # Enterprise Roles tab
#   elsif @sb[:tabform] == "operations_4"
#     @temp[:roles] = UiTaskSet.all.sort_by{ |role| role[:description] }
    end
  end

  def get_smartproxy_choices
    @smartproxy_choices = Hash.new
    MiqProxy.all.each do |mp|
      @smartproxy_choices[mp.name] = mp.id
    end
  end

  def set_workers_verify_status
    w = @edit[:new].config[:workers][:worker_base][:replication_worker][:replication][:destination]
    @edit[:default_verify_status] = (w[:password] == w[:verify])
  end

  def move_cols_left_right(direction)
    flds = direction == "right" ? "available_fields" : "selected_fields"
    hosts = direction == "right" ? "available_hosts" : "selected_hosts"
    sort_hosts = direction == "right" ? "selected_hosts" : "available_hosts"
    if !params["#{flds}".to_sym] || params["#{flds}".to_sym].length == 0 || params["#{flds}".to_sym][0] == ""
      add_flash(I18n.t("flash.edit.no_fields_to_move.#{direction}", :field=>"fields"), :error)
    else
      @edit[:new][@edit[:new][:selected_server][0]]["#{hosts}".to_sym].each do |af|                 # Go thru all available columns
        if params["#{flds}".to_sym].include?(af)        # See if this column was selected to move
          @edit[:new][@edit[:new][:selected_server][0]]["#{sort_hosts}".to_sym].push(af)                      # Add it to the new fields list
        end
      end
      @edit[:new][@edit[:new][:selected_server][0]]["#{hosts}".to_sym].delete_if{|af| params["#{flds}".to_sym].include?(af)} # Remove selected fields
      @edit[:new][@edit[:new][:selected_server][0]]["#{sort_hosts}".to_sym].sort!                 # Sort the selected fields array
      @refresh_div = "hosts_lists"
      @refresh_partial = "hosts_lists"
    end
  end

  def build_smartproxy_affinity_node(zone, server, node_type)
    affinities = server.send("vm_scan_#{node_type}_affinity").collect(&:id)
    {
      :key      => "#{server.id}__#{node_type}",
      :icon     => "#{node_type}.png",
      :title    => Dictionary.gettext(node_type.camelcase, :type => :model, :notfound => :titleize).pluralize,
      :children => zone.send(node_type.pluralize).sort_by(&:name).collect do |node|
        {
          :key    => "#{server.id}__#{node_type}_#{node.id}",
          :icon   => "#{node_type}.png",
          :title  => node.name,
          :select => affinities.include?(node.id)
        }
      end
    }
  end

  def build_smartproxy_affinity_tree(zone)
    zone.miq_servers.select { |s| s.is_a_proxy? }.sort_by { |s| [s.name, s.id] }.collect do |s|
      title = "#{Dictionary.gettext('MiqServer', :type => :model, :notfound => :titleize)}: #{s.name} [#{s.id}]"
      title = "<b class='cfme-bold-node'>#{title} (current)</title>".html_safe if @sb[:my_server_id] == s.id
      {
        :key      => s.id.to_s,
        :icon     => 'evm_server.png',
        :title    => title,
        :expand   => true,
        :children => [build_smartproxy_affinity_node(zone, s, 'host'),
                      build_smartproxy_affinity_node(zone, s, 'storage')]
      }
    end
  end
end
