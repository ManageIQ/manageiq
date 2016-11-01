module Mixins
  module EmsCommonAngular
    extend ActiveSupport::Concern

    def index
      redirect_to :action => 'show_list'
    end

    def update
      assert_privileges("#{permission_prefix}_edit")
      case params[:button]
      when "cancel"   then update_ems_button_cancel
      when "save"     then update_ems_button_save
      when "validate" then update_ems_button_validate
      end
    end

    def update_ems_button_cancel
      update_ems = find_by_id_filtered(model, params[:id])
      model_name = model.to_s
      flash_msg = _("Edit of %{model} \"%{name}\" was cancelled by the user") %
                  {:model => ui_lookup(:model => model_name),
                   :name  => update_ems.name}
      ems_path = ems_path(update_ems, :flash_msg => flash_msg)
      if @lastaction == "show"
        javascript_redirect ems_path
      else
        javascript_redirect :action    => @lastaction,
                            :id        => update_ems.id,
                            :display   => session[:ems_display],
                            :flash_msg => flash_msg
      end
    end

    def update_ems_button_save
      update_ems = find_by_id_filtered(model, params[:id])
      set_ems_record_vars(update_ems)
      if update_ems.save
        update_ems.reload
        flash = _("%{model} \"%{name}\" was saved") %
                {:model => ui_lookup(:model => model.to_s),
                 :name  => update_ems.name}
        construct_edit_for_audit(update_ems)
        AuditEvent.success(build_saved_audit(update_ems, @edit))
        update_ems.authentication_check_types_queue(update_ems.authentication_for_summary.pluck(:authtype),
                                                    :save => true)
        ems_path = ems_path(update_ems, :flash_msg => flash)
        javascript_redirect ems_path
      else
        update_ems.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        drop_breadcrumb(:name => _("Edit %{table} '%{name}'") %
          {:table => ui_lookup(:table => @table_name), :name => update_ems.name},
                        :url  => "/#{@table_name}/edit/#{update_ems.id}")
        @in_a_form = true
        render_flash
      end
    end

    def update_ems_button_validate(verify_ems = nil)
      verify_ems ||= find_by_id_filtered(model, params[:id])
      set_ems_record_vars(verify_ems, :validate)
      @in_a_form = true
      result, details = verify_ems.authentication_check(params[:cred_type],
                                                        :save     => false,
                                                        :database => params[:metrics_database_name])

      if result
        add_flash(_("Credential validation was successful"))
      else
        add_flash(_("Credential validation was not successful: %{details}") % {:details => details}, :error)
      end

      render :json => {:message => @flash_array.last(1)[0][:message], :level => @flash_array.last(1)[0][:level]}
    end

    def create
      assert_privileges("#{permission_prefix}_new")

      case params[:button]
      when "add" then create_ems_button_add
      when "validate" then create_ems_button_validate
      when "cancel" then create_ems_button_cancel
      end
    end

    def create_ems_button_add
      ems = model.model_from_emstype(params[:emstype]).new
      set_ems_record_vars(ems) unless @flash_array
      if ems.valid? && ems.save
        construct_edit_for_audit(ems)
        AuditEvent.success(build_created_audit(ems, @edit))
        flash_msg = _("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:tables => @table_name),
                                                           :name  => ems.name}
        javascript_redirect :action    => 'show_list',
                            :flash_msg => flash_msg
      else
        @in_a_form = true
        ems.errors.each do |field, msg|
          add_flash("#{ems.class.human_attribute_name(field)} #{msg}", :error)
        end

        drop_breadcrumb(:name => _("Add New %{tables}") % {:tables => ui_lookup(:tables => table_name)},
                        :url  => new_ems_path)
        javascript_flash
      end
    end

    def create_ems_button_validate
      ems = model.model_from_emstype(params[:emstype]).new
      update_ems_button_validate(ems)
    end

    def create_ems_button_cancel
      model_name = model.to_s
      javascript_redirect :action    => @lastaction,
                          :display   => session[:ems_display],
                          :flash_msg => _("Add of %{model} was cancelled by the user") %
                          {:model => ui_lookup(:model => model_name)}
    end

    def ems_form_fields
      assert_privileges("#{permission_prefix}_edit")
      @ems = model.new if params[:id] == 'new'
      @ems = find_by_id_filtered(model, params[:id]) if params[:id] != 'new'
      default_security_protocol = @ems.default_endpoint.security_protocol ? @ems.default_endpoint.security_protocol : 'ssl'

      if @ems.zone.nil? || @ems.my_zone == ""
        zone = "default"
      else
        zone = @ems.my_zone
      end
      amqp_userid = ""
      amqp_hostname = ""
      amqp_port = ""
      amqp_security_protocol = ""
      ssh_keypair_userid = ""
      metrics_userid = ""
      metrics_hostname = ""
      metrics_port = ""
      metrics_database_name = ""
      keystone_v3_domain_id = ""
      hawkular_hostname = ""
      hawkular_api_port = ""

      if @ems.connection_configurations.amqp.try(:endpoint)
        amqp_hostname = @ems.connection_configurations.amqp.endpoint.hostname
        amqp_port = @ems.connection_configurations.amqp.endpoint.port
        amqp_security_protocol = @ems.connection_configurations.amqp.endpoint.security_protocol ? @ems.connection_configurations.amqp.endpoint.security_protocol : 'ssl'
      end
      if @ems.has_authentication_type?(:amqp)
        amqp_userid = @ems.has_authentication_type?(:amqp) ? @ems.authentication_userid(:amqp).to_s : ""
        amqp_auth_status = @ems.authentication_status_ok?(:amqp)
      end

      if @ems.has_authentication_type?(:ssh_keypair)
        ssh_keypair_userid = @ems.has_authentication_type?(:ssh_keypair) ? @ems.authentication_userid(:ssh_keypair).to_s : ""
        ssh_keypair_auth_status = @ems.authentication_status_ok?(:ssh_keypair)
      end

      if @ems.connection_configurations.metrics.try(:endpoint)
        metrics_hostname = @ems.connection_configurations.metrics.endpoint.hostname
        metrics_port = @ems.connection_configurations.metrics.endpoint.port
        metrics_database_name = @ems.connection_configurations.metrics.endpoint.path
      end

      if @ems.has_authentication_type?(:metrics)
        metrics_userid = @ems.has_authentication_type?(:metrics) ? @ems.authentication_userid(:metrics).to_s : ""
        metrics_auth_status = @ems.authentication_status_ok?(:metrics)
      end

      if @ems.respond_to?(:keystone_v3_domain_id)
        keystone_v3_domain_id = @ems.keystone_v3_domain_id
      end

      if @ems.connection_configurations.hawkular.try(:endpoint)
        hawkular_hostname = @ems.connection_configurations.hawkular.endpoint.hostname
        hawkular_api_port = @ems.connection_configurations.hawkular.endpoint.port
        hawkular_auth_status = @ems.authentication_status_ok?(:hawkular)
      end

      if @ems.connection_configurations.default.try(:endpoint)
        default_hostname = @ems.connection_configurations.default.endpoint.hostname
        default_api_port = @ems.connection_configurations.default.endpoint.port
      else
        default_hostname = @ems.hostname
        default_api_port = @ems.port
      end

      @ems_types = Array(model.supported_types_and_descriptions_hash.invert).sort_by(&:first)

      if @ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
        host_default_vnc_port_start = @ems.host_default_vnc_port_start.to_s
        host_default_vnc_port_end = @ems.host_default_vnc_port_end.to_s
      end

      if @ems.kind_of?(ManageIQ::Providers::Azure::CloudManager)
        azure_tenant_id = @ems.azure_tenant_id
        subscription    = @ems.subscription
        client_id       = @ems.authentication_userid ? @ems.authentication_userid : ""
        client_key      = @ems.authentication_password ? @ems.authentication_password : ""
      end

      if @ems.kind_of?(ManageIQ::Providers::Google::CloudManager)
        project         = @ems.project
        service_account = @ems.authentication_token
        service_account_auth_status = @ems.authentication_status_ok?
      end

      default_auth_status = @ems.authentication_status_ok? unless @ems.kind_of?(ManageIQ::Providers::Google::CloudManager)

      render :json => {:name                            => @ems.name,
                       :emstype                         => @ems.emstype,
                       :zone                            => zone,
                       :tenant_mapping_enabled          => @ems.tenant_mapping_enabled == true,
                       :provider_id                     => @ems.provider_id ? @ems.provider_id : "",
                       :hostname                        => @ems.hostname,
                       :default_hostname                => default_hostname,
                       :amqp_hostname                   => amqp_hostname,
                       :default_api_port                => default_api_port ? default_api_port : "",
                       :amqp_api_port                   => amqp_port ? amqp_port : "",
                       :api_version                     => @ems.api_version ? @ems.api_version : "v2",
                       :default_security_protocol       => default_security_protocol,
                       :amqp_security_protocol          => amqp_security_protocol,
                       :provider_region                 => @ems.provider_region,
                       :openstack_infra_providers_exist => retrieve_openstack_infra_providers.length > 0,
                       :default_userid                  => @ems.authentication_userid ? @ems.authentication_userid : "",
                       :amqp_userid                     => amqp_userid,
                       :service_account                 => service_account ? service_account : "",
                       :azure_tenant_id                 => azure_tenant_id ? azure_tenant_id : "",
                       :keystone_v3_domain_id           => keystone_v3_domain_id,
                       :subscription                    => subscription ? subscription : "",
                       :client_id                       => client_id ? client_id : "",
                       :client_key                      => client_key ? client_key : "",
                       :project                         => project ? project : "",
                       :emstype_vm                      => @ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager),
                       :event_stream_selection          => retrieve_event_stream_selection,
                       :ems_controller                  => controller_name,
                       :default_auth_status             => default_auth_status,
                       :amqp_auth_status                => amqp_auth_status,
                       :service_account_auth_status     => service_account_auth_status
      } if controller_name == "ems_cloud" || controller_name == "ems_network"

      render :json => { :name                          => @ems.name,
                        :emstype                       => @ems.emstype,
                        :zone                          => zone,
                        :provider_id                   => @ems.provider_id ? @ems.provider_id : "",
                        :default_hostname              => @ems.connection_configurations.default.endpoint.hostname,
                        :amqp_hostname                 => amqp_hostname,
                        :metrics_hostname              => metrics_hostname,
                        :metrics_database_name         => metrics_database_name,
                        :metrics_default_database_name => metrics_default_database_name,
                        :default_api_port              => default_api_port ? default_api_port : "",
                        :amqp_api_port                 => amqp_port ? amqp_port : "",
                        :metrics_api_port              => metrics_port ? metrics_port : "",
                        :default_security_protocol     => default_security_protocol,
                        :amqp_security_protocol        => amqp_security_protocol,
                        :api_version                   => @ems.api_version ? @ems.api_version : "v2",
                        :provider_region               => @ems.provider_region,
                        :default_userid                => @ems.authentication_userid ? @ems.authentication_userid : "",
                        :amqp_userid                   => amqp_userid,
                        :ssh_keypair_userid            => ssh_keypair_userid,
                        :metrics_userid                => metrics_userid,
                        :keystone_v3_domain_id         => keystone_v3_domain_id,
                        :emstype_vm                    => @ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager),
                        :host_default_vnc_port_start   => host_default_vnc_port_start ? host_default_vnc_port_start : "",
                        :host_default_vnc_port_end     => host_default_vnc_port_end ? host_default_vnc_port_end : "",
                        :event_stream_selection        => retrieve_event_stream_selection,
                        :ems_controller                => controller_name,
                        :default_auth_status           => default_auth_status,
                        :metrics_auth_status           => metrics_auth_status.nil? ? true : metrics_auth_status,
                        :ssh_keypair_auth_status       => ssh_keypair_auth_status.nil? ? true : ssh_keypair_auth_status
      } if controller_name == "ems_infra"

      render :json => {:name                      => @ems.name,
                       :emstype                   => @ems.emstype,
                       :zone                      => zone,
                       :provider_id               => @ems.provider_id ? @ems.provider_id : "",
                       :hostname                  => @ems.hostname,
                       :default_hostname          => @ems.connection_configurations.default.endpoint.hostname,
                       :hawkular_hostname         => hawkular_hostname,
                       :default_api_port          => @ems.connection_configurations.default.endpoint.port,
                       :hawkular_api_port         => hawkular_api_port,
                       :api_version               => @ems.api_version ? @ems.api_version : "v2",
                       :default_security_protocol => default_security_protocol,
                       :provider_region           => @ems.provider_region,
                       :default_userid            => @ems.authentication_userid ? @ems.authentication_userid : "",
                       :service_account           => service_account ? service_account : "",
                       :bearer_token_exists       => @ems.authentication_token(:bearer).nil? ? false : true,
                       :ems_controller            => controller_name,
                       :default_auth_status       => default_auth_status,
                       :hawkular_auth_status      => hawkular_auth_status.nil? ? true : hawkular_auth_status,
      } if controller_name == "ems_container"

      render :json => {:name                => @ems.name,
                       :emstype             => @ems.emstype,
                       :zone                => zone,
                       :default_hostname    => @ems.connection_configurations.default.endpoint.hostname,
                       :default_api_port    => @ems.connection_configurations.default.endpoint.port,
                       :default_userid      => @ems.authentication_userid ? @ems.authentication_userid : "",
                       :ems_controller      => controller_name,
                       :default_auth_status => default_auth_status,
      } if controller_name == "ems_middleware"
    end

    private ############################

    def metrics_default_database_name
      if @ems.class.name == 'ManageIQ::Providers::Redhat::InfraManager'
        ManageIQ::Providers::Redhat::InfraManager.history_database_name_for('4.0')
      end
    end

    def table_name
      self.class.table_name
    end

    def no_blank(thing)
      thing.blank? ? nil : thing
    end

    def set_ems_record_vars(ems, mode = nil)
      ems.name                   = params[:name].strip if params[:name]
      ems.provider_region        = params[:provider_region]
      ems.api_version            = params[:api_version].strip if params[:api_version]
      ems.provider_id            = params[:provider_id]
      ems.zone                   = Zone.find_by_name(params[:zone])
      ems.tenant_mapping_enabled = params[:tenant_mapping_enabled] == "on" if ems.class.supports_cloud_tenant_mapping?
      ems.security_protocol      = params[:default_security_protocol].strip if params[:default_security_protocol]

      hostname = params[:default_hostname].strip if params[:default_hostname]
      port = params[:default_api_port].strip if params[:default_api_port]
      amqp_hostname = params[:amqp_hostname].strip if params[:amqp_hostname]
      amqp_port = params[:amqp_api_port].strip if params[:amqp_api_port]
      amqp_security_protocol = params[:amqp_security_protocol].strip if params[:amqp_security_protocol]
      metrics_hostname = params[:metrics_hostname].strip if params[:metrics_hostname]
      metrics_port = params[:metrics_api_port].strip if params[:metrics_api_port]
      metrics_database_name = params[:metrics_database_name].strip if params[:metrics_database_name]
      hawkular_hostname = params[:hawkular_hostname].strip if params[:hawkular_hostname]
      hawkular_api_port = params[:hawkular_api_port].strip if params[:hawkular_api_port]
      default_endpoint = {}
      amqp_endpoint = {}
      ceilometer_endpoint = {}
      ssh_keypair_endpoint = {}
      metrics_endpoint = {}
      hawkular_endpoint = {}

      if ems.kind_of?(ManageIQ::Providers::Openstack::CloudManager) || ems.kind_of?(ManageIQ::Providers::Openstack::InfraManager)
        default_endpoint = {:role => :default, :hostname => hostname, :port => port, :security_protocol => ems.security_protocol}
        ems.keystone_v3_domain_id = params[:keystone_v3_domain_id]
        if params[:event_stream_selection] == "amqp"
          amqp_endpoint = {:role => :amqp, :hostname => amqp_hostname, :port => amqp_port, :security_protocol => amqp_security_protocol}
        else
          ceilometer_endpoint = {:role => :ceilometer}
        end
      end

      ssh_keypair_endpoint = {:role => :ssh_keypair} if ems.kind_of?(ManageIQ::Providers::Openstack::InfraManager)

      if ems.kind_of?(ManageIQ::Providers::Redhat::InfraManager)
        default_endpoint = {:role => :default, :hostname => hostname, :port => port, :security_protocol => ems.security_protocol}
        metrics_endpoint = { :role     => :metrics,
                             :hostname => metrics_hostname,
                             :port     => metrics_port,
                             :path     => metrics_database_name }
      end

      if ems.kind_of?(ManageIQ::Providers::Google::CloudManager)
        ems.project = params[:project]
      end

      if ems.kind_of?(ManageIQ::Providers::Microsoft::InfraManager)
        default_endpoint = {:role => :default, :hostname => hostname, :security_protocol => ems.security_protocol}
        ems.realm = params[:realm]
      end

      if ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
        default_endpoint = {:role => :default, :hostname => hostname}
        ems.host_default_vnc_port_start = params[:host_default_vnc_port_start].blank? ? nil : params[:host_default_vnc_port_start].to_i
        ems.host_default_vnc_port_end = params[:host_default_vnc_port_end].blank? ? nil : params[:host_default_vnc_port_end].to_i
      end

      if ems.kind_of?(ManageIQ::Providers::Vmware::CloudManager)
        default_endpoint = {:role => :default, :hostname => hostname, :port => port}
        if params[:event_stream_selection] == "amqp"
          amqp_endpoint = {:role => :amqp, :hostname => amqp_hostname, :port => amqp_port, :security_protocol => amqp_security_protocol}
        end
      end

      if ems.kind_of?(ManageIQ::Providers::Azure::CloudManager)
        ems.azure_tenant_id = params[:azure_tenant_id]
        ems.subscription    = params[:subscription] unless params[:subscription].blank?
      end

      if ems.kind_of?(ManageIQ::Providers::ContainerManager)
        params[:cred_type] = ems.default_authentication_type if params[:cred_type] == "default"
        ems.hostname = hostname
        hawkular_hostname = hostname if hawkular_hostname.blank?

        default_endpoint = {:role => :default, :hostname => hostname, :port => port}
        hawkular_endpoint = {:role => :hawkular, :hostname => hawkular_hostname, :port => hawkular_api_port}
      end

      if ems.kind_of?(ManageIQ::Providers::Hawkular::MiddlewareManager)
        default_endpoint = {:role => :default, :hostname => hostname, :port => port}
      end

      if ems.kind_of?(ManageIQ::Providers::Nuage::NetworkManager)
        default_endpoint = {:role => :default, :hostname => hostname, :port => port, :security_protocol => ems.security_protocol}
      end

      endpoints = {:default     => default_endpoint,
                   :ceilometer  => ceilometer_endpoint,
                   :amqp        => amqp_endpoint,
                   :ssh_keypair => ssh_keypair_endpoint,
                   :metrics     => metrics_endpoint,
                   :hawkular    => hawkular_endpoint}

      build_connection(ems, endpoints, mode)
    end

    def build_connection(ems, endpoints, mode)
      authentications = build_credentials(ems, mode)
      configurations = []

      [:default, :ceilometer, :amqp, :ssh_keypair, :metrics, :hawkular].each do |role|
        configurations << build_configuration(ems, authentications, endpoints, role)
      end

      ems.connection_configurations = configurations
    end

    def build_configuration(ems, authentications, endpoints, role)
      authtype = role == :default ? ems.default_authentication_type.to_sym : role
      return {:endpoint => endpoints[role], :authentication => nil} unless authentications[authtype]

      authentication = authentications.delete(authtype)
      authentication[:role] = authtype.to_s
      authentication[:authtype] = authtype.to_s
      {:endpoint => endpoints[role], :authentication => authentication}
    end

    def build_credentials(ems, mode)
      creds = {}
      if params[:default_userid]
        default_password = params[:default_password] ? params[:default_password] : ems.authentication_password
        creds[:default] = {:userid => params[:default_userid], :password => default_password, :save => (mode != :validate)}
      end
      if ems.supports_authentication?(:amqp) && params[:amqp_userid]
        amqp_password = params[:amqp_password] ? params[:amqp_password] : ems.authentication_password(:amqp)
        creds[:amqp] = {:userid => params[:amqp_userid], :password => amqp_password, :save => (mode != :validate)}
      end
      if ems.kind_of?(ManageIQ::Providers::Openstack::InfraManager) &&
         ems.supports_authentication?(:ssh_keypair) && params[:ssh_keypair_userid]
        ssh_keypair_password = params[:ssh_keypair_password] ? params[:ssh_keypair_password].gsub(/\r\n/, "\n") : ems.authentication_key(:ssh_keypair)
        creds[:ssh_keypair] = {:userid => params[:ssh_keypair_userid], :auth_key => ssh_keypair_password, :save => (mode != :validate)}
      end
      if ems.kind_of?(ManageIQ::Providers::Redhat::InfraManager) &&
         ems.supports_authentication?(:metrics) && params[:metrics_userid]
        metrics_password = params[:metrics_password] ? params[:metrics_password] : ems.authentication_password(:metrics)
        creds[:metrics] = {:userid => params[:metrics_userid], :password => metrics_password, :save => (mode != :validate)}
      end
      if ems.supports_authentication?(:auth_key) && params[:service_account]
        creds[:default] = {:auth_key => params[:service_account], :userid => "_", :save => (mode != :validate)}
      end
      if ems.supports_authentication?(:oauth) && !session[:oauth_response].blank?
        auth = session[:oauth_response]
        credentials = auth["credentials"]
        creds[:oauth] = {:refresh_token => credentials["refresh_token"],
                         :access_token  => credentials["access_token"],
                         :expires       => credentials["expires"],
                         :userid        => auth["info"]["name"],
                         :save          => (mode != :validate)}
        session[:oauth_response] = nil
      end
      if ems.kind_of?(ManageIQ::Providers::ContainerManager)
        default_key = params[:default_password] ? params[:default_password] : ems.authentication_key
        creds[:hawkular] = {:auth_key => default_key, :save => (mode != :validate)}
        creds[:bearer] = {:auth_key => default_key, :save => (mode != :validate)}
        creds.delete(:default)
      end
      creds
    end

    def retrieve_event_stream_selection
      return "amqp" if @ems.connection_configurations.ceilometer.try(:endpoint).nil? && @ems.connection_configurations.amqp.try(:endpoint)
      "ceilometer"
    end

    def construct_edit_for_audit(ems)
      @edit ||= {}
      ems.kind_of?(ManageIQ::Providers::Azure::CloudManager) ? azure_tenant_id = ems.azure_tenant_id : azure_tenant_id = nil
      @edit[:current] = {
        :name                  => ems.name,
        :provider_region       => ems.provider_region,
        :hostname              => ems.hostname,
        :azure_tenant_id       => azure_tenant_id,
        :keystone_v3_domain_id => ems.respond_to?(:keystone_v3_domain_id) ? ems.keystone_v3_domain_id : nil,
        :subscription          => ems.subscription,
        :port                  => ems.port,
        :api_version           => ems.api_version,
        :security_protocol     => ems.security_protocol,
        :provider_id           => ems.provider_id,
        :zone                  => ems.zone
      }

      @edit[:current][:tenant_mapping_enabled] = ems.tenant_mapping_enabled if ems.class.supports_cloud_tenant_mapping?

      @edit[:new] = {:name                  => params[:name],
                     :provider_region       => params[:provider_region],
                     :hostname              => params[:hostname],
                     :azure_tenant_id       => params[:azure_tenant_id],
                     :keystone_v3_domain_id => params[:keystone_v3_domain_id],
                     :port                  => params[:port],
                     :api_version           => params[:api_version],
                     :security_protocol     => params[:default_security_protocol],
                     :provider_id           => params[:provider_id],
                     :zone                  => params[:zone]
      }

      @edit[:new][:tenant_mapping_enabled] = params[:tenant_mapping_enabled] if ems.class.supports_cloud_tenant_mapping?
    end
  end
end
