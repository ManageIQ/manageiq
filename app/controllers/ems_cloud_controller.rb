class EmsCloudController < ApplicationController
  include EmsCommon        # common methods for EmsInfra/Cloud controllers

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def self.model
    ManageIQ::Providers::CloudManager
  end

  def self.table_name
    @table_name ||= "ems_cloud"
  end

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
    render :update do |page|
      if @lastaction == "show"
        page.redirect_to ems_cloud_path(update_ems, :flash_msg => flash_msg)
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
      render :update do |page|
        page.redirect_to ems_cloud_path(update_ems, :flash_msg => flash)
      end
      return
    else
      update_ems.errors.each do |field, msg|
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
      end
      drop_breadcrumb(:name => "Edit #{ui_lookup(:table => @table_name)} '#{update_ems.name}'",
                      :url  => "/#{@table_name}/edit/#{update_ems.id}")
      @in_a_form = true
      render_flash
    end
  end

  def update_ems_button_validate(verify_ems = nil)
    verify_ems ||= find_by_id_filtered(model, params[:id])
    set_ems_record_vars(verify_ems, :validate)
    @in_a_form = true

    save = params[:id] == "new" ? false : true
    result, details = verify_ems.authentication_check(params[:cred_type], :save => save)
    if result
      add_flash(_("Credential validation was successful"))
    else
      add_flash(_("Credential validation was not successful: %s") % details, :error)
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
        page.redirect_to :action    => 'show_list',
                         :flash_msg => flash_msg
      end
    else
      @in_a_form = true
      ems.errors.each do |field, msg|
        add_flash("#{ems.class.human_attribute_name(field)} #{msg}", :error)
      end

      drop_breadcrumb(:name => "Add New #{ui_lookup(:tables => table_name)}", :url => new_ems_cloud_path)
      render :update do |page|
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
      page.redirect_to(:action    => @lastaction,
                       :display   => session[:ems_display],
                       :flash_msg => _("Add of %{model} was cancelled by the user") %
                           {:model => ui_lookup(:model => model_name)})
    end
  end

  def ems_cloud_form_fields
    assert_privileges("#{permission_prefix}_edit")
    @ems = model.new if params[:id] == 'new'
    @ems = find_by_id_filtered(model, params[:id]) if params[:id] != 'new'

    if @ems.zone.nil? || @ems.my_zone == ""
      zone = "default"
    else
      zone = @ems.my_zone
    end

    metrics_userid = @ems.has_authentication_type?(:metrics) ? @ems.authentication_userid(:metrics).to_s : ""
    metrics_password = @ems.has_authentication_type?(:metrics) ? @ems.authentication_password(:metrics).to_s : ""
    metrics_verify = @ems.has_authentication_type?(:metrics) ? @ems.authentication_password(:metrics).to_s : ""

    amqp_userid = @ems.has_authentication_type?(:amqp) ? @ems.authentication_userid(:amqp).to_s : ""
    amqp_password = @ems.has_authentication_type?(:amqp) ? @ems.authentication_password(:amqp).to_s : ""
    amqp_verify = @ems.has_authentication_type?(:amqp) ? @ems.authentication_password(:amqp).to_s : ""

    ssh_keypair_userid = @ems.has_authentication_type?(:ssh_keypair) ? @ems.authentication_userid(:ssh_keypair).to_s : ""
    ssh_keypair_password = @ems.has_authentication_type?(:ssh_keypair) ? @ems.authentication_key(:ssh_keypair).to_s : ""

    bearer_token = @ems.has_authentication_type?(:bearer) ? @ems.authentication_token(:bearer).to_s : ""
    bearer_verify = @ems.has_authentication_type?(:bearer) ? @ems.authentication_token(:bearer).to_s : ""

    if @ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
      host_default_vnc_port_start = @ems.host_default_vnc_port_start.to_s
      host_default_vnc_port_end = @ems.host_default_vnc_port_end.to_s
    end

    if @ems.kind_of?(ManageIQ::Providers::Azure::CloudManager)
      azure_tenant_id = @ems.azure_tenant_id
      client_id       = @ems.authentication_userid ? @ems.authentication_userid : ""
      client_key      = @ems.authentication_password ? @ems.authentication_password : ""
    end

    render :json => {:name                            => @ems.name,
                     :emstype                         => @ems.emstype,
                     :zone                            => zone,
                     :provider_id                     => @ems.provider_id ? @ems.provider_id : "",
                     :hostname                        => @ems.hostname,
                     :api_port                        => @ems.port,
                     :provider_region                 => @ems.provider_region,
                     :openstack_infra_providers_exist => retrieve_openstack_infra_providers.length > 0 ? true : false,
                     :default_userid                  => @ems.authentication_userid ? @ems.authentication_userid : "",
                     :default_password                => @ems.authentication_password ? @ems.authentication_password : "",
                     :default_verify                  => @ems.authentication_password ? @ems.authentication_password : "",
                     :metrics_userid                  => metrics_userid,
                     :metrics_password                => metrics_password,
                     :metrics_verify                  => metrics_verify,
                     :amqp_userid                     => amqp_userid,
                     :amqp_password                   => amqp_password,
                     :amqp_verify                     => amqp_verify,
                     :ssh_keypair_userid              => ssh_keypair_userid,
                     :ssh_keypair_password            => ssh_keypair_password,
                     :bearer_token                    => bearer_token,
                     :bearer_verify                   => bearer_verify,
                     :azure_tenant_id                 => azure_tenant_id ? azure_tenant_id : "",
                     :client_id                       => client_id ? client_id : "",
                     :client_key                      => client_key ? client_key : "",
                     :host_default_vnc_port_start     => host_default_vnc_port_start,
                     :host_default_vnc_port_end       => host_default_vnc_port_end,
                     :emstype_vm                      => @ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
                    }
  end

  private ############################

  def table_name
    self.class.table_name
  end

  def no_blank(thing)
    thing.blank? ? nil : thing
  end

  def get_session_data
    @title      = ui_lookup(:tables => "ems_cloud")
    @layout     = "ems_cloud"
    @table_name = request.parameters[:controller]
    @lastaction = session[:ems_cloud_lastaction]
    @display    = session[:ems_cloud_display]
    @filters    = session[:ems_cloud_filters]
    @catinfo    = session[:ems_cloud_catinfo]
  end

  def set_session_data
    session[:ems_cloud_lastaction] = @lastaction
    session[:ems_cloud_display]    = @display unless @display.nil?
    session[:ems_cloud_filters]    = @filters
    session[:ems_cloud_catinfo]    = @catinfo
  end

  def show_link(ems, options = {})
    ems_cloud_path(ems.id, options)
  end

  def set_ems_record_vars(ems, mode = nil)
    ems.name            = params[:name]
    ems.provider_region = params[:provider_region]
    ems.hostname        = params[:hostname]
    ems.port            = params[:api_port]
    ems.provider_id     = params[:provider_id]
    ems.zone            = Zone.find_by_name(params[:zone])

    if ems.kind_of?(ManageIQ::Providers::Microsoft::InfraManager)
      ems.security_protocol = params[:security_protocol]
      ems.realm = params[:realm]
    end

    if ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
      ems.host_default_vnc_port_start = params[:host_default_vnc_port_start].blank? ? nil : params[:host_default_vnc_port_start].to_i
      ems.host_default_vnc_port_end = params[:host_default_vnc_port_end].blank? ? nil : params[:host_default_vnc_port_end].to_i
    end

    ems.azure_tenant_id = params[:azure_tenant_id] if ems.kind_of?(ManageIQ::Providers::Azure::CloudManager)

    creds = {}
    creds[:default] = {:userid   => params[:default_userid],
                       :password => params[:default_password]} unless params[:default_userid].blank?
    if ems.supports_authentication?(:metrics) && !params[:metrics_userid].blank?
      creds[:metrics] = {:userid => params[:metrics_userid], :password => params[:metrics_password]}
    end
    if ems.supports_authentication?(:amqp) && !params[:amqp_userid].blank?
      creds[:amqp] = {:userid => params[:amqp_userid], :password => params[:amqp_password]}
    end
    if ems.supports_authentication?(:ssh_keypair) && !params[:ssh_keypair_userid].blank?
      creds[:ssh_keypair] = {:userid => params[:ssh_keypair_userid], :auth_key => params[:ssh_keypair_password]}
    end
    if ems.supports_authentication?(:bearer) && !params[:bearer_token].blank?
      creds[:bearer] = {:auth_key => params[:bearer_token], :userid => "_"} # Must have userid
    end

    ems.update_authentication(creds, :save => (mode != :validate))
  end

  def construct_edit_for_audit(ems)
    @edit ||= {}
    ems.kind_of?(ManageIQ::Providers::Azure::CloudManager) ? azure_tenant_id = ems.azure_tenant_id : azure_tenant_id = nil;
    @edit[:current] = {:name            => ems.name,
                       :provider_region => ems.provider_region,
                       :hostname        => ems.hostname,
                       :azure_tenant_id => azure_tenant_id,
                       :port            => ems.port,
                       :provider_id     => ems.provider_id,
                       :zone            => ems.zone
    }
    @edit[:new] = {:name            => params[:name],
                   :provider_region => params[:provider_region],
                   :hostname        => params[:hostname],
                   :azure_tenant_id => params[:azure_tenant_id],
                   :port            => params[:port],
                   :provider_id     => params[:provider_id],
                   :zone            => params[:zone]
    }
  end

  def restful?
    true
  end
end
