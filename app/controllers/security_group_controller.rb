class SecurityGroupController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericButtonMixin
  include Mixins::GenericListMixin
  include Mixins::GenericSessionMixin
  include Mixins::GenericShowMixin

  def self.display_methods
    %w(instances network_ports)
  end

  menu_section :net

  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:display] = @display if %w(vms instances images).include?(@display)
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh

    @refresh_div = "main_div"

    case params[:pressed]
    when "security_group_tag"
      return tag("SecurityGroup")
    when 'security_group_delete'
      delete_security_groups
    when "security_group_edit"
      checked_security_group_id = get_checked_security_group_id(params)
      javascript_redirect :action => "edit", :id => checked_security_group_id
    else
      if params[:pressed] == "security_group_new"
        javascript_redirect :action => "new"
      elsif !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  def cancel_action(message)
    session[:edit] = nil
    @breadcrumbs.pop if @breadcrumbs
    javascript_redirect :action    => @lastaction,
                        :id        => @security_group.id,
                        :display   => session[:security_group_display],
                        :flash_msg => message
  end

  def security_group_form_fields
    assert_privileges("security_group_edit")
    security_group = find_by_id_filtered(SecurityGroup, params[:id])
    render :json => {
      :name              => security_group.name,
      :description       => security_group.description,
      :cloud_tenant_name => security_group.cloud_tenant.try(:name),
    }
  end

  def create
    assert_privileges("security_group_new")
    case params[:button]
    when "cancel"
      javascript_redirect :action    => 'show_list',
                          :flash_msg => _("Add of new Security Group was cancelled by the user")
    when "add"
      @security_group = SecurityGroup.new
      options = form_params
      ems = ExtManagementSystem.find(options[:ems_id])
      if SecurityGroup.class_by_ems(ems).supports_create?
        options.delete(:ems_id)
        task_id = ems.create_security_group_queue(session[:userid], options)

        add_flash(_("Security Group creation: Task start failed: ID [%{id}]") %
                  {:id => task_id.to_s}, :error) unless task_id.kind_of?(Fixnum)

        if @flash_array
          javascript_flash(:spinner_off => true)
        else
          initiate_wait_for_task(:task_id => task_id, :action => "create_finished")
        end
      else
        @in_a_form = true
        add_flash(_(SecurityGroup.unsupported_reason(:create)), :error)
        drop_breadcrumb(:name => _("Add New Security Group "), :url  => "/security_group/new")
        javascript_flash
      end
    end
  end

  def create_finished
    task_id = session[:async][:params][:task_id]
    security_group_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Security Group \"%{name}\" created") % { :name  => security_group_name })
    else
      add_flash(_("Unable to create Security Group \"%{name}\": %{details}") % {
        :name    => security_group_name,
        :details => task.message
      }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show_list"
  end

  def delete_security_groups
    assert_privileges("security_group_delete")

    security_groups = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "security_group")
                        find_checked_items
                      else
                        [params[:id]]
                      end

    if security_groups.empty?
      add_flash(_("No Securty Group were selected for deletion."), :error)
    end

    security_groups_to_delete = []
    security_groups.each do |s|
      security_group = SecurityGroup.find(s)
      if security_group.nil?
        add_flash(_("Security Group no longer exists."), :error)
      elsif security_group.supports_delete?
        security_groups_to_delete.push(security_group)
      else
        add_flash(_("Couldn't initiate deletion of Security Group \"%{name}\": %{details}") % {
          :name    => security_group.name,
          :details => security_group.unsupported_reason(:delete)
        }, :error)
      end
    end
    process_security_groups(security_groups_to_delete, "destroy") unless security_groups_to_delete.empty?

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "security_group"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected Security Group was deleted"))
      else # or (if we deleted what we were showing) we redirect to the listing
        javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message]
      end
    end
  end

  def edit
    assert_privileges("security_group_edit")
    @security_group = find_by_id_filtered(SecurityGroup, params[:id])
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Edit Security Group \"%{name}\"") % { :name  => @security_group.name},
      :url  => "/security_group/edit/#{@security_group.id}")
  end

  def get_checked_security_group_id(params)
    if params[:id]
      checked_security_group_id = params[:id]
    else
      checked_security_groups = find_checked_items
      checked_security_group_id = checked_security_groups[0] if checked_security_groups.length == 1
    end
    checked_security_group_id
  end

  def new
    assert_privileges("security_group_new")
    @security_group = SecurityGroup.new
    @in_a_form = true

    @ems_choices = {}
    ExtManagementSystem.where(:type => "ManageIQ::Providers::Openstack::NetworkManager").find_each do |ems|
      @ems_choices[ems.name] = ems.id
    end

    @cloud_tenant_choices = {}
    CloudTenant.all.each { |tenant| @cloud_tenant_choices[tenant.name] = tenant.id }

    drop_breadcrumb(:name => _("Add New Security Group"), :url => "/security_group/new")
  end

  def update
    assert_privileges("security_group_edit")
    @security_group = find_by_id_filtered(SecurityGroup, params[:id])
    options = form_params
    case params[:button]
    when "cancel"
      cancel_action(_("Edit of Security Group \"%{name}\" was cancelled by the user") % {
        :name => @security_group.name
      })

    when "save"
      if @security_group.supports_update?
        task_id = @security_group.update_security_group_queue(session[:userid], options)
        add_flash(_("Security Group update failed: Task start failed: ID [%{id}]") %
                  {:id => task_id.to_s}, :error) unless task_id.kind_of?(Fixnum)
        if @flash_array
          javascript_flash(:spinner_off => true)
        else
          initiate_wait_for_task(:task_id => task_id, :action => "update_finished")
        end
      else
        add_flash(_("Couldn't initiate update of Security Group \"%{name}\": %{details}") % {
          :name    => @security_group.name,
          :details => @security_group.unsupported_reason(:delete)
        }, :error)
      end
    end
  end

  def update_finished
    task_id = session[:async][:params][:task_id]
    security_group_id = session[:async][:params][:id]
    security_group_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Security Group \"%{name}\" updated") % { :name => security_group_name })
    else
      add_flash(_("Unable to update Security Group \"%{name}\": %{details}") % {
        :name    => security_group_name,
        :details => task.message
      }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show", :id => security_group_id
  end

  private

  def form_params
    options = {}
    options[:name] = params[:name] if params[:name]
    options[:description] = params[:description] if params[:description]
    options[:ems_id] = params[:ems_id] if params[:ems_id]
    options[:cloud_tenant] = find_by_id_filtered(CloudTenant, params[:cloud_tenant_id]) if params[:cloud_tenant_id]
    options
  end

  # dispatches operations to multiple security_groups
  def process_security_groups(security_groups, operation)
    return if security_groups.empty?

    if operation == "destroy"
      security_groups.each do |security_group|
        audit = {
          :event        => "security_group_record_delete_initiated",
          :message      => "[#{security_group.name}] Record delete initiated",
          :target_id    => security_group.id,
          :target_class => "SecurityGroup",
          :userid       => session[:userid]
        }
        AuditEvent.success(audit)
        security_group.delete_security_group_queue(session[:userid])
      end
      add_flash(n_("Delete initiated for %{number} Security Group.",
                   "Delete initiated for %{number} Security Groups.",
                   security_groups.length) % {:number => security_groups.length})
    end
  end
end
