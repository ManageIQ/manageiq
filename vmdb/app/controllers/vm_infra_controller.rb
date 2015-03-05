class VmInfraController < ApplicationController
  include VmCommon        # common methods for vm controllers
  include VmShowMixin

  # Exception due to open.window() in newer IE versions not sending request.referer
  before_filter :check_privileges, :except => [:launch_vmware_console]
  before_filter :get_session_data

  after_filter :cleanup_action
  after_filter :set_session_data

  private

  def features
    [
      ApplicationController::Feature.new("vandt_accord",
                                         :vandt,
                                         "vandt",
                                         :vandt_tree,
                                         "VMs & Templates",
                                         "vandt_tree_div"),

      ApplicationController::Feature.new("vms_filter_accord",
                                         :filter,
                                         "vms_filter",
                                         :vms_filter_tree,
                                         "VMs",
                                         "vms_filter_tree_div"),

      ApplicationController::Feature.new("templates_filter_accord",
                                         :filter,
                                         "templates_filter",
                                         :templates_filter_tree,
                                         "Templates",
                                         "templates_filter_tree_div"),
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
      set_active_elements_authorized_user("#{prefix}_filter_tree", "#{prefix}_filter", false, nil)
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

  def set_active_elements(feature)
    if feature
      self.x_active_tree   ||= feature.tree_list_name
      self.x_active_accord ||= feature.accord_name
    end
    get_node_info(x_node)
  end
end
