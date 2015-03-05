class VmCloudController < ApplicationController
  include VmCommon        # common methods for vm controllers
  include VmShowMixin

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  private

  def features
    [
      ApplicationController::Feature.new_with_hash(
        :role        => "instances_accord",
        :name        => :instances,
        :accord_name => "instances",
        :tree_name   => :instances_tree,
        :title       => "Instances by Provider",
        :container   => "instances_tree_div"),

      ApplicationController::Feature.new_with_hash(
        :role        => "images_accord",
        :name        => :images,
        :accord_name => "images",
        :tree_name   => :images_tree,
        :title       => "Images by Provider",
        :container   => "images_tree_div"),

      ApplicationController::Feature.new_with_hash(
        :role        => "instances_filter_accord",
        :name        => :filter,
        :accord_name => "instances_filter",
        :tree_name   => :instances_filter_tree,
        :title       => "Instances",
        :container   => "instances_filter_tree_div"),

      ApplicationController::Feature.new_with_hash(
        :role        => "images_filter_accord",
        :name        => :filter,
        :accord_name => "images_filter",
        :tree_name   => :images_filter_tree,
        :title       => "Images",
        :container   => "images_filter_tree_div")
    ]
  end

  # redefine get_filters from VmShow
  def get_filters
    session[:instances_filters]
  end

  def prefix_by_nodetype(nodetype)
    case TreeBuilder.get_model_for_prefix(nodetype).underscore
    when "miq_template" then "images"
    when "vm"           then "instances"
    end
  end

  def set_elements_and_redirect_unauthorized_user
    @nodetype, id = params[:id].split("_").last.split("-")
    prefix = prefix_by_nodetype(@nodetype)

    # Position in tree that matches selected record
    if role_allows(:feature => "instances_accord") && prefix == "instances"
      set_active_elements_authorized_user('instances_tree', 'instances', true, VmCloud, id)
    elsif role_allows(:feature => "images_accord") && prefix == "images"
      set_active_elements_authorized_user('images_tree', 'images', true, TemplateCloud, id)
    elsif role_allows(:feature => "#{prefix}_filter_accord")
      set_active_elements_authorized_user("#{prefix}_filter_tree", "#{prefix}_filter", false, nil, nil)
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
end
