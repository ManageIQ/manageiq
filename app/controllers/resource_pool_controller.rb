class ResourcePoolController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin
  include Mixins::GenericSessionMixin
  include Mixins::GenericShowMixin

  def self.display_methods
    %w(vms descendant_vms all_vms)
  end

  def display_descendant_vms
    @showtype = "config"
    drop_breadcrumb(:name => _("%{name} (All VMs - Tree View)") % {:name => @record.name},
                    :url  => "/resource_pool/show/#{@record.id}?display=descendant_vms&treestate=true")
    self.x_active_tree = :datacenter_tree
    @datacenter_tree = TreeBuilderDatacenter.new(:datacenter_tree, :datacenter, @sb, true, @record)
  end

  def display_vms
    nested_list(_("(Direct VMs)"), Vm, "all_vms")
  end

  def display_all_vms
    nested_list({:table => "vms"}, Vm)
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["all_vms", "vms", "resource_pools"].include?(@display)  # Were we displaying sub-items
    if ["all_vms", "vms", "resource_pools"].include?(@display)                  # Need to check, since RPs contain RPs

      if params[:pressed].starts_with?("vm_", # Handle buttons from sub-items screen
                                       "miq_template_",
                                       "guest_")

        pfx = pfx_for_vm_button_pressed(params[:pressed])
        process_vm_buttons(pfx)

        return if ["#{pfx}_policy_sim", "#{pfx}_compare", "#{pfx}_tag", "#{pfx}_protect",
                   "#{pfx}_retire", "#{pfx}_right_size", "#{pfx}_ownership",
                   "#{pfx}_reconfigure"].include?(params[:pressed]) &&
                  @flash_array.nil?   # Some other screen is showing, so return

        unless ["#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone",
                "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
          @refresh_div = "main_div"
          @refresh_partial = "layouts/gtl"
          show
        end
      end
    else
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      tag(ResourcePool) if params[:pressed] == "resource_pool_tag"
      deleteresourcepools if params[:pressed] == "resource_pool_delete"
      assign_policies(ResourcePool) if params[:pressed] == "resource_pool_protect"
    end

    return if ["resource_pool_tag", "resource_pool_protect"].include?(params[:pressed]) && @flash_array.nil?   # Tag screen showing, so return

    check_if_button_is_implemented

    if !@flash_array.nil? && params[:pressed] == "resource_pool_delete" && @single_delete
      javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message] # redirect to build the retire screen
    elsif ["#{pfx}_miq_request_new", "#{pfx}_migrate", "#{pfx}_clone",
           "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      render_or_redirect_partial(pfx)
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  menu_section :inf
end
