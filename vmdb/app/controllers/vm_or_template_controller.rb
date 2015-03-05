class VmOrTemplateController < ApplicationController
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
      ApplicationController::Feature.new("vms_instances_filter_accord",
                                         :filter,
                                         "vms_instances_filter",
                                         :vms_instances_filter_tree,
                                         "VMs & Instances",
                                         "vms_instances_filter_tree_div"),

      ApplicationController::Feature.new("templates_images_filter_accord",
                                         :filter,
                                         "templates_images_filter",
                                         :templates_images_filter_tree,
                                         "Templates & Images",
                                         "templates_images_filter_tree_div"),
    ]
  end

  def prefix_by_nodetype(nodetype)
    case TreeBuilder.get_model_for_prefix(nodetype).underscore
    when "miq_template" then "templates_images"
    when "vm"           then "vms_instances"
    end
  end

  def set_elements_and_redirect_unauthorized_user
    @nodetype, _ = params[:id].split("_").last.split("-")
    prefix = prefix_by_nodetype(@nodetype)

    # Position in tree that matches selected record
    if role_allows(:feature => "#{prefix}_filter_accord")
      set_active_elements_authorized_user("#{prefix}_filter_tree", "#{prefix}_filter", false, nil, nil)
    else
      redirect_to(:controller => 'dashboard', :action => "auth_error")
      return true
    end
    nodetype, id = params[:id].split("-")
    self.x_node = "#{nodetype}-#{to_cid(id)}"
    get_node_info(x_node)
  end

  def set_active_elements
    # Set active tree and accord to first allowed feature
    if role_allows(:feature => "vms_instances_filter_accord")
      self.x_active_tree   ||= 'vms_instances_filter_tree'
      self.x_active_accord ||= 'vms_instances_filter'
    elsif role_allows(:feature => "templates_images_filter_accord")
      self.x_active_tree   ||= 'templates_images_filter_tree'
      self.x_active_accord ||= 'templates_images_filter'
    end
    get_node_info(x_node)
  end
end
