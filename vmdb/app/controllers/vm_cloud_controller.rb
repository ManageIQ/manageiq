class VmCloudController < ApplicationController
  include VmCommon        # common methods for vm controllers
  include VmShowMixin

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  private

  Feature = Struct.new :role, :name, :accord_name, :tree_name, :title, :container

  def features
    [
      Feature.new("instances_accord",
                  :instances,
                  "instances",
                  :instances_tree,
                  "Instances by Provider",
                  "instances_tree_div"),

      Feature.new("images_accord",
                  :images,
                  "images",
                  :images_tree,
                  "Images by Provider",
                  "images_tree_div"),

      Feature.new("instances_filter_accord",
                  :filter,
                  "instances_filter",
                  :instances_filter_tree,
                  "Instances",
                  "instances_filter_tree_div"),

      Feature.new("images_filter_accord",
                  :filter,
                  "images_filter",
                  :images_filter_tree,
                  "Images",
                  "images_filter_tree_div")
    ]
  end

  def build_trees_and_accordions
    @trees   = []
    @accords = []
    features.each do |feature|
      if role_allows(:feature=> feature.role)
        build_vm_tree(feature.name, feature.tree_name)  # Build V&T tree
        @trees.push(feature.tree_name.to_s)
        @accords.push({:name=>feature.accord_name, :title=>feature.title, :container=>feature.container})
      end
    end
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

  def set_active_elements
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
    # Set active tree and accord to first allowed feature
    get_node_info(x_node)
  end
end
