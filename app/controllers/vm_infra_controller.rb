class VmInfraController < ApplicationController
  include VmCommon        # common methods for vm controllers
  include VmShowMixin

  # Exception due to open.window() in newer IE versions not sending request.referer
  before_action :check_privileges, :except => [:launch_vmware_console]
  before_action :get_session_data

  after_action :cleanup_action
  after_action :set_session_data

  def self.table_name
    @table_name ||= "vm_infra"
  end

  private

  def features
    [
      ApplicationController::Feature.new_with_hash(
        :role  => "vandt_accord",
        :name  => :vandt,
        :title => _("VMs & Templates")),

      ApplicationController::Feature.new_with_hash(
        :role  => "vms_filter_accord",
        :name  => :vms_filter,
        :title => _("VMs"),),

      ApplicationController::Feature.new_with_hash(
        :role  => "templates_filter_accord",
        :name  => :templates_filter,
        :title => _("Templates"),),
    ]
  end

  def prefix_by_nodetype(nodetype)
    case TreeBuilder.get_model_for_prefix(nodetype).underscore
    when "miq_template" then "templates"
    when "vm"           then "vms"
    end
  end

  def set_elements_and_redirect_unauthorized_user
    @nodetype, id = params[:id].split("_").last.split("-")
    prefix = prefix_by_nodetype(@nodetype)

    # Position in tree that matches selected record
    if role_allows(:feature => "vandt_accord")
      set_active_elements_authorized_user('vandt_tree', 'vandt', true, VmOrTemplate, id)
    elsif role_allows(:feature => "#{prefix}_filter_accord")
      set_active_elements_authorized_user("#{prefix}_filter_tree", "#{prefix}_filter", false, nil, id)
    else
      if (prefix == "vms" && role_allows(:feature => "vms_instances_filter_accord")) ||
         (prefix == "templates" && role_allows(:feature => "templates_images_filter_accord"))
        redirect_to(:controller => 'vm_or_template', :action => "explorer", :id => params[:id])
      else
        redirect_to(:controller => 'dashboard', :action => "auth_error")
      end
      return true
    end
    nodetype, id = params[:id].split("-")
    self.x_node = "#{nodetype}-#{to_cid(id)}"
    get_node_info(x_node)
  end

  def tagging_explorer_controller?
    @explorer
  end

  def skip_breadcrumb?
    breadcrumb_prohibited_for_action?
  end
end
