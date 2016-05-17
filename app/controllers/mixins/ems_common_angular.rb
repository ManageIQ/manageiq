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
      render :update do |page|
        page << javascript_prologue
        if @lastaction == "show"
          page.redirect_to ems_path
        else
          page.redirect_to(:action    => @lastaction,
                           :id        => update_ems.id,
                           :display   => session[:ems_display],
                           :flash_msg => flash_msg)
        end
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
        ems_path = ems_path(update_ems, :flash_msg => flash)
        render :update do |page|
          page << javascript_prologue
          page.redirect_to ems_path
        end
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

      result, details = verify_ems.authentication_check(params[:cred_type], :save => false)

      if result
        add_flash(_("Credential validation was successful"))
      else
        add_flash(_("Credential validation was not successful: %{details}") % {:details => details}, :error)
      end

      render_flash
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
        render :update do |page|
          page << javascript_prologue
          page.redirect_to :action    => 'show_list',
                           :flash_msg => flash_msg
        end
      else
        @in_a_form = true
        ems.errors.each do |field, msg|
          add_flash("#{ems.class.human_attribute_name(field)} #{msg}", :error)
        end

        drop_breadcrumb(:name => _("Add New %{tables}") % {:tables => ui_lookup(:tables => table_name)},
                        :url  => new_ems_path)
        render :update do |page|
          page << javascript_prologue
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
    end

    def create_ems_button_validate
      ems = model.model_from_emstype(params[:emstype]).new
      update_ems_button_validate(ems)
    end

    def create_ems_button_cancel
      model_name = model.to_s
      render :update do |page|
        page << javascript_prologue
        page.redirect_to(:action    => @lastaction,
                         :display   => session[:ems_display],
                         :flash_msg => _("Add of %{model} was cancelled by the user") %
                             {:model => ui_lookup(:model => model_name)})
      end
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
      keystone_v3_domain_id = ""

      if @ems.connection_configurations.amqp.try(:endpoint)
        amqp_hostname = @ems.connection_configurations.amqp.endpoint.hostname
        amqp_port = @ems.connection_configurations.amqp.endpoint.port
        amqp_security_protocol = @ems.connection_configurations.amqp.endpoint.security_protocol ? @ems.connection_configurations.amqp.endpoint.security_protocol : 'ssl'
      end
      if @ems.has_authentication_type?(:amqp)
        amqp_userid = @ems.has_authentication_type?(:amqp) ? @ems.authentication_userid(:amqp).to_s : ""
      end

      if @ems.has_authentication_type?(:ssh_keypair)
        ssh_keypair_userid = @ems.has_authentication_type?(:ssh_keypair) ? @ems.authentication_userid(:ssh_keypair).to_s : ""
      end

      if @ems.connection_configurations.metrics.try(:endpoint)
        metrics_hostname = @ems.connection_configurations.metrics.endpoint.hostname
        metrics_port = @ems.connection_configurations.metrics.endpoint.port
      end
      if @ems.has_authentication_type?(:metrics)
        metrics_userid = @ems.has_authentication_type?(:metrics) ? @ems.authentication_userid(:metrics).to_s : ""
      end

      if @ems.respond_to?(:keystone_v3_domain_id)
        keystone_v3_domain_id = @ems.keystone_v3_domain_id
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
      end

      render :json => {:name                            => @ems.name,
                       :emstype                         => @ems.emstype,
                       :zone                            => zone,
                       :provider_id                     => @ems.provider_id ? @ems.provider_id : "",
                       :hostname                        => @ems.hostname,
                       :default_hostname                => @ems.connection_configurations.default.endpoint.hostname,
                       :amqp_hostname                   => amqp_hostname,
                       :default_api_port                => @ems.connection_configurations.default.endpoint.port,
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
                       :ems_controller                  => controller_name
      } if controller_name == "ems_cloud" || controller_name == "ems_network"

      render :json => {:name                        => @ems.name,
                       :emstype                     => @ems.emstype,
                       :zone                        => zone,
                       :provider_id                 => @ems.provider_id ? @ems.provider_id : "",
                       :default_hostname            => @ems.connection_configurations.default.endpoint.hostname,
                       :amqp_hostname               => amqp_hostname,
                       :metrics_hostname            => metrics_hostname,
                       :default_api_port            => @ems.connection_configurations.default.endpoint.port,
                       :amqp_api_port               => amqp_port ? amqp_port : "",
                       :metrics_api_port            => metrics_port ? metrics_port : "",
                       :default_security_protocol   => default_security_protocol,
                       :amqp_security_protocol      => amqp_security_protocol,
                       :api_version                 => @ems.api_version ? @ems.api_version : "v2",
                       :provider_region             => @ems.provider_region,
                       :default_userid              => @ems.authentication_userid ? @ems.authentication_userid : "",
                       :amqp_userid                 => amqp_userid,
                       :ssh_keypair_userid          => ssh_keypair_userid,
                       :metrics_userid              => metrics_userid,
                       :keystone_v3_domain_id       => keystone_v3_domain_id,
                       :emstype_vm                  => @ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager),
                       :host_default_vnc_port_start => host_default_vnc_port_start ? host_default_vnc_port_start : "",
                       :host_default_vnc_port_end   => host_default_vnc_port_end ? host_default_vnc_port_end : "",
                       :event_stream_selection      => retrieve_event_stream_selection,
                       :ems_controller              => controller_name
      } if controller_name == "ems_infra"
    end

    private ############################

    def table_name
      self.class.table_name
    end

    def no_blank(thing)
      thing.blank? ? nil : thing
    end

    def set_ems_record_vars(ems, mode = nil)
      ems.name              = params[:name].strip if params[:name]
      ems.provider_region   = params[:provider_region]
      ems.api_version       = params[:api_version].strip if params[:api_version]
      ems.provider_id       = params[:provider_id]
      ems.zone              = Zone.find_by_name(params[:zone])
      ems.security_protocol = params[:default_security_protocol].strip if params[:default_security_protocol]

      hostname = params[:default_hostname].strip if params[:default_hostname]
      port = params[:default_api_port].strip if params[:default_api_port]
      amqp_hostname = params[:amqp_hostname].strip if params[:amqp_hostname]
      amqp_port = params[:amqp_api_port].strip if params[:amqp_api_port]
      amqp_security_protocol = params[:amqp_security_protocol].strip if params[:amqp_security_protocol]
      metrics_hostname = params[:metrics_hostname].strip if params[:metrics_hostname]
      metrics_port = params[:metrics_api_port].strip if params[:metrics_api_port]
      default_endpoint = {}
      amqp_endpoint = {}
      ceilometer_endpoint = {}
      ssh_keypair_endpoint = {}
      metrics_endpoint = {}

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
        metrics_endpoint = {:role => :metrics, :hostname => metrics_hostname, :port => metrics_port}
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

      if ems.kind_of?(ManageIQ::Providers::Azure::CloudManager)
        ems.azure_tenant_id = params[:azure_tenant_id]
        ems.subscription    = params[:subscription] unless params[:subscription].blank?
      end

      build_connection(ems, default_endpoint, amqp_endpoint, ceilometer_endpoint, ssh_keypair_endpoint, metrics_endpoint, mode)
    end

    def build_connection(ems, default_endpoint, amqp_endpoint, ceilometer_endpoint, ssh_keypair_endpoint, metrics_endpoint, mode)
      authentications = build_credentials(ems, mode)
      default_authentication = authentications.delete(:default)
      default_authentication[:role] = :default
      amqp_authentication = {}
      ceilometer_authentication = {}
      ssh_keypair_authentication = {}
      metrics_authentication = {}

      if authentications[:amqp]
        amqp_authentication = authentications.delete(:amqp)
        amqp_authentication[:role] = :amqp
      end

      if authentications[:ceilometer]
        ceilometer_authentication = authentications.delete(:ceilometer)
        ceilometer_authentication[:role] = :ceilometer
      end

      if authentications[:ssh_keypair]
        ssh_keypair_authentication = authentications.delete(:ssh_keypair)
        ssh_keypair_authentication[:role] = :ssh_keypair
      end

      if authentications[:metrics]
        metrics_authentication = authentications.delete(:metrics)
        metrics_authentication[:role] = :metrics
      end

      ems.connection_configurations=([{:endpoint => default_endpoint, :authentication => default_authentication},
                                      {:endpoint => amqp_endpoint, :authentication => amqp_authentication},
                                      {:endpoint => ceilometer_endpoint, :authentication => ceilometer_authentication},
                                      {:endpoint => ssh_keypair_endpoint, :authentication => ssh_keypair_authentication},
                                      {:endpoint => metrics_endpoint, :authentication => metrics_authentication}])
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
        ssh_keypair_password = params[:ssh_keypair_password] ? params[:ssh_keypair_password] : ems.authentication_key(:ssh_keypair)
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
    end
  end
end
