class VmCloudController < ApplicationController
  include VmCommon        # common methods for vm controllers
  include VmShowMixin

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  private

  def build_trees_and_accordions
    @trees   = []
    @accords = []
    if role_allows(:feature=>"instances_accord")
      build_vm_tree(:instances, :instances_tree)  # Build V&T tree
      @trees.push("instances_tree")
      @accords.push({:name=>"instances", :title=>"Instances by Provider", :container=>"instances_tree_div"})
    end
    if role_allows(:feature=>"images_accord")
      build_vm_tree(:images, :images_tree)  # Build V&T tree
      @trees.push("images_tree")
      @accords.push({:name=>"images", :title=>"Images by Provider", :container=>"images_tree_div"})
    end
    if role_allows(:feature=>"instances_filter_accord")
      build_vm_tree(:filter, :instances_filter_tree) # Build VM filter tree
      @trees.push("instances_filter_tree")
      @accords.push({:name=>"instances_filter", :title=>"Instances", :container=>"instances_filter_tree_div"})
    end
    if role_allows(:feature=>"images_filter_accord")
      build_vm_tree(:filter, :images_filter_tree) # Build Template filter tree
      @trees.push("images_filter_tree")
      @accords.push({:name=>"images_filter", :title=>"Images", :container=>"images_filter_tree_div"})
    end
  end

  # redefine get_filters from VmShow
  def get_filters
    session[:instances_filters]
  end

  def prefix_by_nodetype(nodetype)
    case X_TREE_NODE_PREFIXES[nodetype].underscore
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

  def set_active_elements
    # Set active tree and accord to first allowed feature
    if role_allows(:feature => "instances_accord")
      self.x_active_tree   ||= 'instances_tree'
      self.x_active_accord ||= 'instances'
    elsif role_allows(:feature => "images_accord")
      self.x_active_tree   ||= 'images_tree'
      self.x_active_accord ||= 'images'
    elsif role_allows(:feature => "instances_filter_accord")
      self.x_active_tree   ||= 'instances_filter_tree'
      self.x_active_accord ||= 'instances_filter'
    elsif role_allows(:feature => "images_filter_accord")
      self.x_active_tree   ||= 'images_filter_tree'
      self.x_active_accord ||= 'images_filter'
    end
    get_node_info(x_node)
  end
end
