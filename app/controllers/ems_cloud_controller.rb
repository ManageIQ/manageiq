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
    return super unless "save" == params[:button]

    assert_privileges("#{permission_prefix}_edit")

    @ems = find_by_id_filtered(model, params[:id])
    set_model_data @ems, params

    if @ems.valid? && @ems.save
      @ems.reload
      flash = _("%{model} \"%{name}\" was saved") %
              {:model => ui_lookup(:model => model.to_s), :name => @ems.name}

      # AuditEvent.success(build_saved_audit(update_ems, @edit))

      render :update do |page|
        page.redirect_to ems_cloud_path(@ems, :flash_msg => flash)
      end
    else
      @ems.errors.each do |field, msg|
        add_flash("#{@ems.class.human_attribute_name(field)} #{msg}", :error)
      end
      drop_breadcrumb(:name => "Edit #{ui_lookup(:table => @table_name)} '#{@ems.name}'",
                      :url  => edit_ems_path(@ems))
      render_flash
    end
  end

  def create
    return super unless "add" == params[:button]

    assert_privileges("#{permission_prefix}_new")

    if params[:server_emstype].blank?
      add_flash(_("%s is required") % "Type", :error)
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    else
      @ems = model.model_from_emstype(params[:server_emstype]).new
      set_model_data @ems, params

      name = ui_lookup(:tables => table_name)

      if @ems.valid? && @ems.save
        render :update do |page|
          page.redirect_to :action => 'show_list', :flash_msg => _("%{model} \"%{name}\" was saved") % {:model => name, :name => @ems.name}
        end
      else
        @ems.errors.each do |field, msg|
          add_flash("#{@ems.class.human_attribute_name(field)} #{msg}", :error)
        end

        drop_breadcrumb(:name => "Add New #{name}", :url => new_ems_cloud_path)
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
    end
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

  def set_model_data(ems, params)
    ems.name            = params[:name]
    ems.provider_region = params[:provider_region]
    ems.hostname        = params[:hostname]
    ems.ipaddress       = params[:ipaddress]
    ems.port            = params[:port]
    ems.zone            = Zone.find_by_name(params[:server_zone] || "default")

    if ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
      ems.host_default_vnc_port_start = no_blank(params[:host_default_vnc_port_start])
      ems.host_default_vnc_port_end = no_blank(params[:host_default_vnc_port_end])
    end

    creds = {
      :default => {
        :userid   => no_blank(params[:default_userid]),
        :password => no_blank(params[:default_password]),
        :verify   => no_blank(params[:default_verify]),
      }
    }

    if ems.supports_authentication?(:metrics)
      creds[:metrics] = {
        :userid   => no_blank(params[:metrics_userid]),
        :password => no_blank(params[:metrics_password]),
        :verify   => no_blank(params[:metrics_verify])
      }
    end

    if ems.supports_authentication?(:amqp)
      creds[:amqp] = {
        :userid   => no_blank(params[:amqp_userid]),
        :password => no_blank(params[:amqp_password]),
        :verify   => no_blank(params[:amqp_verify])
      }
    end
    ems.update_authentication(creds)
    ems
  end
end
