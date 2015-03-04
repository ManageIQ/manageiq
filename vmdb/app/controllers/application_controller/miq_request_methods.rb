module ApplicationController::MiqRequestMethods
  extend ActiveSupport::Concern

  # AJAX driven routine to check for changes on the provision form
  def prov_field_changed
    if !params[:tab_id]
      return unless load_edit("prov_edit__#{params[:id]}","show_list")
    else
      @edit = session[:edit]
    end
    if !@edit || (@edit && @edit[:stamp_typ])     #load tab for show screen
      if params[:tab_id]
        @options[:current_tab_key] = params[:tab_id].split('_')[0].to_sym
        @options[:wf].refresh_field_values(@options,session[:userid])
      end
      prov_load_tab
    else
      if params[:tab_id]
        @edit[:new][:current_tab_key] = params[:tab_id].split('_')[0].to_sym
        @edit[:wf].refresh_field_values(@edit[:new],session[:userid])
      end
      refresh_divs = prov_get_form_vars                           # Get changed option, returns true if divs need refreshing
      build_grid if refresh_divs
      changed = (@edit[:new] != @edit[:current])
      render :update do |page|                    # Use JS to update the display
        #Going thru all dialogs to see if model has set any of the dialog display to hide/ignore
        @edit[:wf].get_all_dialogs.keys.each do |d|
          page << "li_id = '#{d}_li';"
          if @edit[:wf].get_dialog(d)[:display] == :show
            page << "miq_jquery_show_hide_tab(li_id, 'show');"
          else
            page << "miq_jquery_show_hide_tab(li_id, 'hide');"
          end
        end
        if refresh_divs
          @edit[:wf].get_all_dialogs.keys.each do |d|
            if @edit[:wf].get_dialog(d)[:display] == :show && d == @edit[:new][:current_tab_key]
              if @edit[:wf].kind_of?(MiqProvisionWorkflow)
                page.replace_html("#{d}_div", :partial=>"/miq_request/prov_dialog", :locals=>{:wf=>@edit[:wf], :dialog=>d})
              elsif @edit[:wf].class.to_s == "VmMigrateWorkflow"
                page.replace_html("#{d}_div", :partial=>"prov_vm_migrate_dialog", :locals=>{:wf=>@edit[:wf], :dialog=>d})
              else
                page.replace_html("#{d}_div", :partial=>"prov_host_dialog", :locals=>{:wf=>@edit[:wf], :dialog=>d})
              end
            end
          end
        end
        if @edit[:new][:schedule_time] && @edit[:new][:schedule_type][0] == "schedule"
          page << "miq_cal_dateFrom = new Date(#{@timezone_offset});"
          page << "miqBuildCalendar();"
        end
        if changed != session[:changed]
          session[:changed] = changed
          page << javascript_for_miq_button_visibility(changed)
        end
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page << "miqSparkle(false);"
      end
    end
  end

  def pre_prov_continue
    if params[:button] == "submit"
      prov_edit
    else
      pre_prov
    end
  end

  # Pre provisioning, select a template
  def pre_prov
    if params[:button] == "cancel"
      req = session[:edit][:req_id] if session[:edit] && session[:edit][:req_id]
      add_flash(_("Add of new %s was cancelled by the user") % "#{session[:edit][:prov_type]} Request")
      session[:flash_msgs] = @flash_array.dup unless session[:edit][:explorer]  # Put msg in session for next transaction to display
      @explorer = session[:edit][:explorer] ? session[:edit][:explorer] : false
      @edit = session[:edit] =  nil                                               # Clear out session[:edit]
      if @explorer
        @sb[:action] = nil
        replace_right_cell
      else
        render :update do |page|
          if @breadcrumbs && (@breadcrumbs.empty? || @breadcrumbs.last[:url] == "/vm/show_list")
            page.redirect_to :action =>"show_list", :controller=>"vm"
          else
            #had to get id from breadcrumbs url, because there is no params[:id] when cancel is pressed on copy Request screen.
            url = @breadcrumbs.last[:url].split('/')
            page.redirect_to :controller=>url[1], :action =>url[2], :id=>url[3]
          end
        end
      end
    elsif params[:button] == "continue"       # Template chosen, start vm provisioning
      params[:button] = nil                   # Clear the incoming button
      @edit = session[:edit]                  # Grab what we need from @edit
      @explorer = @edit[:explorer]

      if @edit[:wf].nil?
        @src_vm_id = @edit[:src_vm_id]          # Hang on to selected VM to populate prov
        @edit = session[:edit] = nil
      else
        @workflow_exists = true
        @src_vm_id = @edit[:wf].last_vm_id
        validate_preprov
      end
      if @flash_array
        render :update do |page|                    # Use JS to update the display
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        @redirect_controller = "miq_request"
        @refresh_partial = "miq_request/prov_edit"
        if @explorer
          @_params[:org_controller] = "vm"        # Set up for prov_edit
          prov_edit
          @sb[:action] = "pre_prov"
          replace_right_cell
        else
          render :update do |page|
            page.redirect_to :controller     => @redirect_controller,
                             :action         => "prov_edit",
                             :src_vm_id      => @src_vm_id,
                             :org_controller => "vm"
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        end
      end
    elsif params[:sort_choice]
      @edit = session[:edit]
      if @edit[:vm_sortcol] == params[:sort_choice]                       # if same column was selected
        @edit[:vm_sortdir] = @edit[:vm_sortdir] == "ASC" ? "DESC" : "ASC"     #   switch around ascending/descending
      else
        @edit[:vm_sortdir] = "ASC"
      end
      @edit[:vm_sortcol] = params[:sort_choice]
      templates = rbac_filtered_objects(@edit[:template_kls].eligible_for_provisioning).sort_by {|a| a.name.downcase}
      self.send("build_vm_grid", templates, @edit[:vm_sortdir], @edit[:vm_sortcol])
      render :update do |page|                        # Use RJS to update the display
        page.replace("pre_prov_div", :partial=>"miq_request/pre_prov")
        page << "miqSparkle(false);"
      end
    elsif params[:sel_id]
      @edit = session[:edit]
      render :update do |page|                        # Use RJS to update the display
        page << "$('#row_#{j_str(@edit[:src_vm_id])}').removeClass('row3');" if @edit[:src_vm_id]
        page << "$('#row_#{j_str(params[:sel_id])}').addClass('row3');"
        session[:changed] = true
        page << javascript_for_miq_button_visibility(session[:changed])
        @edit[:src_vm_id] = params[:sel_id].to_i
      end
    else                                                        # First time in, build pre-provision screen
      @layout = "miq_request_vm"
      @edit = Hash.new
      @edit[:explorer] = @explorer
      @edit[:vm_sortdir] ||= "ASC"
      @edit[:vm_sortcol] ||= "name"
      @edit[:prov_type] = "VM Provision"
      @edit[:template_kls] = get_template_kls
      templates = rbac_filtered_objects(@edit[:template_kls].eligible_for_provisioning).sort_by {|a| a.name.downcase}
      build_vm_grid(templates, @edit[:vm_sortdir],@edit[:vm_sortcol])
      session[:changed] = false                                 # Turn off the submit button
      @edit[:explorer] = true if @explorer
      @in_a_form = true
    end
  end
  alias instance_pre_prov pre_prov
  alias vm_pre_prov pre_prov

  def get_template_kls
    # when clone/migrate buttons are pressed from a sub list view,
    # these buttons are only available on Infra side
    return TemplateInfra if params[:prov_type]
    case request.parameters[:controller]
      when "vm_cloud"
        return TemplateCloud
      when "vm_infra"
        return TemplateInfra
      else
        return MiqTemplate
    end
  end

  # Add/edit a provision request
  def prov_edit
    if params[:button] == "cancel"
      req = MiqRequest.find_by_id(from_cid(session[:edit][:req_id])) if session[:edit] && session[:edit][:req_id]
      add_flash(req && req.id ? _("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>"#{session[:edit][:prov_type]} Request", :name=>req.description} : _("Provision %s was cancelled by the user") % "#{session[:edit][:prov_type]} Request")
      session[:flash_msgs] = @flash_array.dup unless session[:edit][:explorer]  # Put msg in session for next transaction to display
      @explorer = session[:edit][:explorer] ? session[:edit][:explorer] : false
      @edit = session[:edit] =  nil                                               # Clear out session[:edit]
      @breadcrumbs.pop if @breadcrumbs
      prov_request_cancel_submit_response
    elsif params[:button] == "submit"                           # Update or create the request from the workflow with the new options
      prov_req_submit
    else                                                        # First time in, build provision request screen
      case params[:org_controller]
      when "vm"
        @layout = "miq_request_vm"
      when "host"
        @layout = "miq_request_host"
      when "ae"
        @layout = "miq_request_ae"
      else
        @layout = "miq_request_vm"
      end
      if params[:commit] == "Upload" && session.fetch_path(:edit, :new, :sysprep_enabled, 1) == "Sysprep Answer File"
        upload_sysprep_file
        @tabactive = "customize_div"
      else
        if params[:req_id]
          prov_set_form_vars(MiqRequest.find(params[:req_id]))    # Set vars from existing request
          session[:changed] = false                               # Turn off the submit button
        else
          prov_set_form_vars                                      # Set default vars
          session[:changed] = true                                # Turn on the submit button
        end
        @edit[:explorer] = true if @explorer
        @tabactive = "#{@edit[:new][:current_tab_key]}_div"
      end
      drop_breadcrumb( {:name=>"#{params[:req_id] ? "Edit" : "Add"} #{@edit[:prov_type]} Request", :url=>"/vm/provision"} )
      @in_a_form = true
#     render :action=>"show"
    end
  end

  # get the sort column that was clicked on, else use the current one
  def sort_ds_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    field = ["miq_template","vm","service_template"].include?(@edit[:org_controller]) ? :placement_ds_name : :attached_ds
    sort_grid('ds', @edit[:wf].get_field(field,:environment)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_vm_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    sort_grid('vm', @edit[:wf].get_field(:src_vm_id,:service)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_host_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    @edit[:wf].kind_of?(MiqHostProvisionWorkflow) ? sort_grid('host', @edit[:wf].get_field(:src_host_ids, :service)[:values]) : sort_grid('host', @edit[:wf].get_field(:placement_host_name, :environment)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_pxe_img_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    sort_grid('pxe_img', @edit[:wf].get_field(:pxe_image_id,:service)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_iso_img_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    sort_grid('iso_img', @edit[:wf].get_field(:iso_image_id,:service)[:values])
  end

  def sort_windows_image_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    sort_grid('windows_image', @edit[:wf].get_field(:windows_image_id,:service)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_vc_grid
    @edit = session[:edit]
    sort_grid('vc', @edit[:wf].get_field(:sysprep_custom_spec,:customize)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_template_grid
    @edit = session[:edit]
    sort_grid('script', @edit[:wf].get_field(:customization_template_id,:customize)[:values])
  end

  private ############################

  def build_pxe_img_grid(pxe_imgs,sort_order="ASC",sort_by="name")
    @edit[:pxe_img_sortdir] = sort_order
    @edit[:pxe_img_headers] = {
      "name"=>"Name",
      "description"=>"Description"
    }                                                         #Using it to get column display name on screen to show sort by
    @edit[:pxe_img_columns] = ["name","description"] #Using it to get column names for sort
    @edit[:pxe_img_sortcol] = sort_by                 # in case sort column is not set, set the defaults

    sorted = pxe_imgs.sort_by { |pi| pi.deep_send(sort_by).to_s.downcase }
    sorted = sorted.reverse unless sort_order == "ASC"
    @temp[:pxe_imgs] = sorted.uniq
  end

  def build_iso_img_grid(iso_imgs,sort_order="ASC",sort_by="name")
    @edit[:iso_img_sortdir] = sort_order
    @edit[:iso_img_headers] = {
        "name"=>"Name"
    }                                                         #Using it to get column display name on screen to show sort by
    @edit[:iso_img_columns] = ["name"] #Using it to get column names for sort
    @edit[:iso_img_sortcol] = sort_by                 # in case sort column is not set, set the defaults

    sorted = iso_imgs.sort_by { |img| img.deep_send(sort_by).to_s.downcase }
    sorted = sorted.reverse unless sort_order == "ASC"
    @temp[:iso_imgs] = sorted.uniq
  end

  def build_windows_image_grid(windows_images,sort_order="ASC",sort_by="name")
    @edit[:windows_image_sortdir] = sort_order
    @edit[:windows_image_headers] = {
      "name"=>"Name",
      "description"=>"Description"
    }                                                         #Using it to get column display name on screen to show sort by
    @edit[:windows_image_columns] = ["name","description"] #Using it to get column names for sort
    @edit[:windows_image_sortcol] = sort_by                 # in case sort column is not set, set the defaults

    sorted = windows_images.sort_by { |pi| pi.deep_send(sort_by).to_s.downcase }
    sorted = sorted.reverse unless sort_order == "ASC"
    @temp[:windows_images] = sorted.uniq
  end

  def build_host_grid(hosts,sort_order="ASC",sort_by="name")
    # need to set options from @edit/@option based upon calling screen: show/edit
    options = @edit || @options
    options[:host_sortdir] = sort_order
    #non-editable grid for host prov to display hosts being provisoned
    if options[:wf].kind_of?(MiqHostProvisionWorkflow)
      options[:host_headers] = {
        "name"=>"Name",
        "mac_address"=>"MAC Address"
      }                                                         #Using it to get column display name on screen to show sort by
      options[:host_columns] = ["name","mac_address"]     #Using it to get column names for sort
    else
      #editable grid for vm/migrate prov screens
      options[:host_headers] = {
        "name" => "Name",
        "v_total_vms" => "Total VMs",
        "vmm_product" => "Platform",
        "vmm_version" => "Version",
        "state" => "State"
      }                                                         #Using it to get column display name on screen to show sort by
      options[:host_columns] = ["name", "v_total_vms", "vmm_product", "vmm_version", "state"]     #Using it to get column names for sort
    end

    options[:host_sortcol] = sort_by                                          # in case sort column is not set, set the defaults

    integer_fields = ["v_total_vms"]
    post_sort_method = integer_fields.include?(sort_by) ? :to_i : :downcase # no downcase needed for sorting int fields, aded to to_i to avoid situation where space was nil
    sorted = hosts.sort_by { |h| h.deep_send(sort_by).to_s.send(post_sort_method) }
    sorted = sorted.reverse unless sort_order == "ASC"
    @temp[:hosts] = sorted.uniq
  end

  def build_grid
    if @edit[:wf].kind_of?(MiqProvisionWorkflow)
      if @edit[:new][:current_tab_key] == :service
        if @edit[:wf].class.kind_of?(MiqProvisionWorkflow) || @edit[:new][:st_prov_type]
          build_vm_grid(@edit[:wf].get_field(:src_vm_id,:service)[:values],@edit[:vm_sortdir],@edit[:vm_sortcol])
        else
          @temp[:vm] = VmOrTemplate.find_by_id(@edit[:new][:src_vm_id] && @edit[:new][:src_vm_id][0])
        end
        if @edit[:wf].supports_pxe?
          @edit[:pxe_img_sortdir] ||= "ASC"
          @edit[:pxe_img_sortcol] ||= "name"
          @edit[:windows_image_sortdir] ||= "ASC"
          @edit[:windows_image_sortcol] ||= "name"
          build_pxe_img_grid(@edit[:wf].send("allowed_images"),@edit[:pxe_img_sortdir],@edit[:pxe_img_sortcol])
        end
        if @edit[:wf].supports_iso?
          build_iso_img_grid(@edit[:wf].send("allowed_iso_images"),@edit[:iso_img_sortdir],@edit[:iso_img_sortcol])
        end
      elsif @edit[:new][:current_tab_key] == :environment
        build_host_grid(@edit[:wf].get_field(:placement_host_name,:environment)[:values],@edit[:host_sortdir],@edit[:host_sortcol]) if !@edit[:wf].get_field(:placement_host_name,:environment).blank?
        build_ds_grid(@edit[:wf].get_field(:placement_ds_name,:environment)[:values],@edit[:ds_sortdir],@edit[:ds_sortcol]) if !@edit[:wf].get_field(:placement_ds_name,:environment).blank?
      elsif @edit[:new][:current_tab_key] == :customize
        @edit[:template_sortdir] ||= "ASC"
        @edit[:template_sortcol] ||= "name"
        if @edit[:wf].supports_customization_template?
          build_template_grid(@edit[:wf].send("allowed_customization_templates"),@edit[:template_sortdir],@edit[:template_sortcol])
        else
          build_vc_grid(@edit[:wf].get_field(:sysprep_custom_spec,:customize)[:values],@edit[:vc_sortdir],@edit[:vc_sortcol])
        end
        build_ous_tree(@edit[:wf],@edit[:new][:ldap_ous])
        @sb[:vm_os] = VmOrTemplate.find_by_id(@edit[:new][:src_vm_id][0]).platform if @edit[:new][:src_vm_id] && @edit[:new][:src_vm_id][0]
      elsif @edit[:new][:current_tab_key] == :purpose
        build_tags_tree(@edit[:wf],@edit[:new][:vm_tags],true)
      end
    elsif @edit[:wf].class == VmMigrateWorkflow
      if @edit[:new][:current_tab_key] == :environment
        build_host_grid(@edit[:wf].get_field(:placement_host_name,:environment)[:values],@edit[:host_sortdir],@edit[:host_sortcol]) if !@edit[:wf].get_field(:placement_host_name,:environment).blank?
        build_ds_grid(@edit[:wf].get_field(:placement_ds_name,:environment)[:values],@edit[:ds_sortdir],@edit[:ds_sortcol]) if !@edit[:wf].get_field(:placement_ds_name,:environment).blank?
      end
    else
      if @edit[:new][:current_tab_key] == :service
        build_host_grid(@edit[:wf].get_field(:src_host_ids,:service)[:values],@edit[:host_sortdir],@edit[:host_sortcol])
        build_pxe_img_grid(@edit[:wf].get_field(:pxe_image_id,:service)[:values],@edit[:pxe_img_sortdir],@edit[:pxe_img_sortcol])
        build_iso_img_grid(@edit[:wf].get_field(:iso_image_id,:service)[:values],@edit[:iso_img_sortdir],@edit[:iso_img_sortcol]) if @edit[:wf].supports_iso?
      elsif @edit[:new][:current_tab_key] == :purpose
        fld = @edit[:wf].kind_of?(MiqHostProvisionWorkflow) ? "tag_ids" : "vm_tags"
        build_tags_tree(@edit[:wf],@edit[:new]["#{fld}".to_sym],true)
      elsif @edit[:new][:current_tab_key] == :environment
        build_ds_grid(@edit[:wf].get_field(:attached_ds,:environment)[:values],@edit[:ds_sortdir],@edit[:ds_sortcol])
      elsif @edit[:new][:current_tab_key] == :customize
        build_template_grid(@edit[:wf].get_field(:customization_template_id,:customize)[:values],@edit[:template_sortdir],@edit[:template_sortcol])
      end
    end
  end

  def build_vm_grid(vms, sort_order="ASC", sort_by="name")
    @edit[:vm_sortdir] = sort_order
    @edit[:vm_headers] = {
      "name"=>"Name",
      "operating_system.product_name"=>"Operating System",
      "platform"=>"Platform",
      "num_cpu"=>"CPUs",
      "mem_cpu"=>"Memory",
      "allocated_disk_storage"=>"Disk Size",
      "ext_management_system.name"=>ui_lookup(:model=>'ExtManagementSystem'),
      "v_total_snapshots"=>"Snapshots"
    }                                                         #Using it to get column display name on screen to show sort by

    # add tenant column header to cloud workflows only
    @edit[:vm_headers]["cloud_tenant"] = "Tenant" if vms.any? { |vm| vm.respond_to?(:cloud_tenant) }
    @edit[:vm_columns] = ["name","operating_system.product_name","platform","num_cpu","mem_cpu","allocated_disk_storage","ext_management_system.name","v_total_snapshots"]      #Using it to get column names for sort
    # add tenant column to cloud workflows only
    @edit[:vm_columns].insert(2, "cloud_tenant") if vms.any? { |vm| vm.respond_to?(:cloud_tenant) }
    @edit[:vm_sortcol] = sort_by                  # in case sort column is not set, set the defaults
    integer_fields = ["allocated_disk_storage","mem_cpu","num_cpu","v_total_snapshots"]
    post_sort_method = integer_fields.include?(sort_by) ? :to_i : :downcase # no downcase needed for sorting int fields, aded to to_i to avoid situation where space was nil
    sorted = vms.sort_by { |v| v.deep_send(sort_by).to_s.send(post_sort_method) }
    sorted = sorted.reverse unless sort_order == "ASC"
    @temp[:vms] = sorted.uniq
  end

  def build_ds_grid(datastores,sort_order="DESC",sort_by="free_space")
    @edit[:ds_sortdir] = sort_order
    @edit[:ds_headers] = {
      "name"=>"Name",
      "free_space"=>"Free Space",
      "total_space"=>"Total Space"
    }                                                             #Using it to get column display name on screen to show sort by
    @edit[:ds_columns] = ["name","free_space","total_space"]      #Using it to get column names for sort
    @edit[:ds_sortcol] = sort_by                                  # in case sort column is not set, set the defaults

    integer_fields = ["free_space","total_space"]
    post_sort_method = integer_fields.include?(sort_by) ? :to_i : :downcase # no downcase needed for sorting int fields, aded to to_i to avoid situation where space was nil
    sorted = datastores.sort_by { |d| d.deep_send(sort_by).to_s.send(post_sort_method) }
    sorted = sorted.reverse unless sort_order == "ASC"
    @temp[:datastores] = sorted.uniq
  end

  def build_vc_grid(vcs,sort_order="DESC",sort_by="name")
    @edit[:vc_sortdir] = sort_order
    @edit[:vc_headers] = {
      :name=>"Name",
      :description=>"Description",
      :last_update_time=>"Last Updated"
    }                                                             #Using it to get column display name on screen to show sort by
    @edit[:vc_columns] = [:name,:description,:last_update_time]     #Using it to get column names for sort
    @edit[:vc_sortcol] = sort_by                                  # in case sort column is not set, set the defaults

    integer_fields = ["last_update_time"]
    post_sort_method = integer_fields.include?(sort_by) ? :to_i : :downcase # no downcase needed for sorting int fields, aded to to_i to avoid situation where space was nil
    sorted = vcs.sort_by { |vc| vc.deep_send(sort_by).to_s.send(post_sort_method) }
    sorted = sorted.reverse unless sort_order == "ASC"
    @temp[:vcs] = sorted.uniq
  end

  def build_template_grid(templates,sort_order="DESC",sort_by="name")
    @edit[:template_sortdir] = sort_order
    @edit[:template_headers] = {
      :name=>"Name",
      :description=>"Description",
      :last_update_time=>"Last Updated"
    }                                                             #Using it to get column display name on screen to show sort by
    @edit[:template_columns] = [:name,:description,:last_update_time]     #Using it to get column names for sort
    @edit[:template_sortcol] = sort_by                                  # in case sort column is not set, set the defaults

    integer_fields = ["last_update_time"]
    post_sort_method = integer_fields.include?(sort_by) ? :to_i : :downcase # no downcase needed for sorting int fields, aded to to_i to avoid situation where space was nil
    sorted = templates.sort_by { |t| t.deep_send(sort_by).to_s.send(post_sort_method) }
    sorted = sorted.reverse unless sort_order == "ASC"
    @temp[:templates] = sorted.uniq
  end

  def sort_grid(what, values)
    sortdir = "#{what}_sortdir".to_sym
    sortcol = "#{what}_sortcol".to_sym
    unless params[:sort_choice].nil?
      if @edit[sortcol] == params[:sort_choice]                       # if same column was selected
        @edit[sortdir] = @edit[sortdir] == "ASC" ? "DESC" : "ASC"     #   switch around ascending/descending
      else
        @edit[sortdir] = "ASC"
      end
      @edit[sortcol] = params[:sort_choice]
    end

    self.send("build_#{what}_grid", values, @edit[sortdir], @edit[sortcol])
    render :update do |page|                        # Use RJS to update the display
      page.replace("prov_#{what}_div", :partial=>"miq_request/prov_#{what}_grid",:locals=>{:field_id=>params[:field_id]})
      page << "miqSparkle(false);"
    end
  end

  def validate_fields
    # Update/create returned false, validation failed
    @edit[:wf].get_dialog_order.each do |d|                           # Go thru all dialogs, in order that they are displayed
      @edit[:wf].get_all_fields(d).keys.each do |f|                 # Go thru all field
        field = @edit[:wf].get_field(f, d)
        if !field[:error].blank?
          @error_div ||= "#{d}"
          add_flash(field[:error], :error)
        end
      end
    end
  end

  def validate_preprov
    @edit[:wf].get_dialog_order.each do |d|
      @edit[:wf].get_all_fields(d).keys.each do |f|
        field = @edit[:wf].get_field(f, d)
        @edit[:wf].validate(@edit[:new])
        unless field[:error].nil?
          @error_div ||= "#{d}"
          add_flash(field[:error], :error)
        end
      end
    end
  end

  def prov_request_cancel_submit_response
    if @explorer
      @sb[:action] = nil
      replace_right_cell
    else
      render :update do |page|
        if @breadcrumbs && (@breadcrumbs.empty? || @breadcrumbs.last[:url] == "/vm/show_list")
          page.redirect_to :action => "show_list", :controller => "vm"
        else
          # had to get id from breadcrumbs url,
          # because there is no params[:id] when cancel is pressed on copy Request screen.
          url = @breadcrumbs.last[:url].split('/')
          page.redirect_to :controller => url[1], :action => url[2], :id => url[3]
        end
      end
    end
  end

  def prov_req_submit
    id = session[:edit][:req_id] || "new"
    return unless load_edit("prov_edit__#{id}","show_list")
    @edit[:new][:schedule_time] = @edit[:new][:schedule_time].in_time_zone("Etc/UTC") if @edit[:new][:schedule_time]
    request = @edit[:req_id] ? @edit[:wf].update_request(@edit[:req_id], @edit[:new], session[:userid]) : @edit[:wf].create_request(@edit[:new], session[:userid])
    validate_fields
    if !@flash_array
      @breadcrumbs.pop if @breadcrumbs
      typ = @edit[:org_controller]
      case typ
      when "vm"
        title = "VMs"
      when "miq_template"
        title = "Templates"
      else
        title = "Hosts"
      end
      flash = @edit[:req_id] == nil ? _("%{typ} Request was Submitted, you will be notified when your %{title} are ready") % {:typ=>@edit[:prov_type], :title=>title} : _("%{typ} Request was re-submitted, you will be notified when your %{title} are ready") % {:typ=>@edit[:prov_type], :title=>title}
      @explorer = @edit[:explorer] ? @edit[:explorer] : false
      @sb[:action] = @edit = session[:edit] =  nil                                                # Clear out session[:edit]
      if role_allows(:feature => "miq_request_show_list", :any => true)
        render :update do |page|
          page.redirect_to :controller => 'miq_request',
                           :action     => 'show_list',
                           :flash_msg  => flash,
                           :typ        => typ
        end
      else
        add_flash(flash)
        prov_request_cancel_submit_response
      end
    else
      @edit[:new][:current_tab_key] = @error_div.split('_')[0].to_sym if @error_div
      @edit[:wf].refresh_field_values(@edit[:new],session[:userid])
      build_grid
      render :update do |page|                    # Use JS to update the display
        page.replace("prov_wf_div", :partial=>"/miq_request/prov_wf") if @error_div
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  # Get variables from provisioning form
  def prov_get_form_vars
    if params[:ids_checked]                         # User checked/unchecked a tree node
      ids = params[:ids_checked].split(",")
      fld = @edit[:wf].kind_of?(MiqHostProvisionWorkflow) ? "tag_ids" : "vm_tags"
      @edit[:new]["#{fld}".to_sym] = Array.new
      ids.each do |id|
        @edit[:new]["#{fld}".to_sym].push(id.to_i) if id != "" #for some reason if tree is not expanded clicking on radiobuttons this.getAllChecked() sends up extra blanks
      end
    end
    id = params[:ou_id] if params[:ou_id]
    id.gsub!(/_-_/,",") if id
    @edit[:new][:ldap_ous] = id.match(/(.*)\,(.*)/)[1..2] if id                       # ou selected in a tree

    @edit[:new][:start_date]    = params[:miq_date_1] if params[:miq_date_1]
    @edit[:new][:start_hour]    = params[:start_hour] if params[:start_hour]
    @edit[:new][:start_min]     = params[:start_min] if params[:start_min]
    @edit[:new][:schedule_time] = Time.zone.parse("#{@edit[:new][:start_date]} #{@edit[:new][:start_hour]}:#{@edit[:new][:start_min]}")

    params.keys.each do |key|
      next unless key.include?("__")
      d, f  = key.split("__")  # Parse dialog and field names from the parameter key
      field = @edit[:wf].get_field(f.to_sym, d.to_sym)  # Get the field hash
      val   =
        case field[:data_type]  # Get the value, convert to integer or boolean if needed
        when :integer
          params[key].to_i
        when :boolean
          params[key].to_s == "true"
        else
          params[key]
        end

      if field[:values]                                                         # If a choice was made
        if field[:values].kind_of?(Hash)
          #set an array of selected ids for security groups field
          if f == "security_groups"
            if params[key] == ""
              @edit[:new][f.to_sym] = [nil]
            else
              @edit[:new][f.to_sym] = Array.new
              params[key].split(",").each { |v| @edit[:new][f.to_sym].push(v.to_i) }
            end
          else
            @edit[:new][f.to_sym] = [val, field[:values][val]]                    # Save [value, description]
          end
        else
          field[:values].each do |v|
            if v.class.name == "MiqHashStruct" && v.evm_object_class == :Storage
              if ["miq_template","service_template","vm"].include?(@edit[:org_controller])
                if params[key] == "__DS__NONE__"                                  # Added this to deselect datastore in grid
                  @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
                elsif v.id.to_i == val.to_i
                  @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
                end
              else
                if params[key] == "__DS__NONE__"                                  # Added this to deselect datastore in grid
                  @edit[:new][f.to_sym] = Array.new                           # Save [value, description]
                elsif v.id.to_i == val.to_i
                  if @edit[:new][f.to_sym].include?(val)
                    @edit[:new][f.to_sym].delete_if {|x| x == val }
                  else
                    @edit[:new][f.to_sym].push(val)                             # Save [value, description]
                  end

                end
              end
            elsif v.class.name == "MiqHashStruct" && v.evm_object_class == :Host
              if params[key] == "__HOST__NONE__"                                  # Added this to deselect datastore in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id.to_i == val.to_i
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            elsif v.class.name == "MiqHashStruct" && v.evm_object_class == :Vm
              if params[key] == "__VM__NONE__"                                  # Added this to deselect datastore in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id.to_i == val.to_i
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            elsif v.class.name == "MiqHashStruct" && (v.evm_object_class == :PxeImage || v.evm_object_class == :WindowsImage)
              if params[key] == "__PXE_IMG__NONE__"                                 # Added this to deselect datastore in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id == val
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            elsif v.class.name == "MiqHashStruct" && v.evm_object_class == :IsoImage
              if params[key] == "__ISO_IMG__NONE__"                                 # Added this to deselect datastore in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id == val
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            elsif v.class.name == "MiqHashStruct" && v.evm_object_class == :CustomizationTemplate
              if params[key] == "__TEMPLATE__NONE__"                                  # Added this to deselect datastore in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id.to_i == val.to_i
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            elsif v.kind_of?(VimHash) || (v.class.name == "MiqHashStruct" && v.evm_object_class == :CustomizationSpec)
              if params[key] == "__VC__NONE__"                                  # Added this to deselect custom_spec in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id.to_i == val.to_i
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            else
              if v[1].to_i == val.to_i
                @edit[:new][f.to_sym] = [val, v[0]]                             # Save [value, description]
              end
            end
          end
        end
        begin
          @edit[:wf].refresh_field_values(@edit[:new],session[:userid])           # Refresh the workflow with new field values based on options, need to pass userid there
        rescue StandardError => bang
          add_flash(bang, :error)
          @edit[:new][f.to_sym] = val                                             # Save value
          return false                                                            # No need to refresh dialog divs
        else
          return true
        end                                                                   # Return true, refresh dialog divs
      else
        @edit[:new][f.to_sym] = val                                             # Save value
        return false                                                            # No need to refresh dialog divs
      end
    end
  end

  def prov_set_show_vars
    @showtype = "main"
    @options = @miq_request.get_options                         # Get the provision options from the request record
    @options[:org_controller] = @miq_request.resource_type == "MiqHostProvisionRequest" ? "host" : "vm"
    if @options[:schedule_time]
      @options[:schedule_time] = format_timezone(@options[:schedule_time],Time.zone,"raw")
      @options[:start_date] = "#{@options[:schedule_time].month}/#{@options[:schedule_time].day}/#{@options[:schedule_time].year}"  # Set the start date
      @options[:start_hour] = "#{@options[:schedule_time].hour}"
      @options[:start_min] = "#{@options[:schedule_time].min}"
    end
    drop_breadcrumb( {:name=>@miq_request.description.to_s.split(' submitted')[0], :url=>"/miq_request/show/#{@miq_request.id}"} )
    if @miq_request.workflow_class
      options = Hash.new
      begin
        options[:wf] = @miq_request.workflow_class.new(@options,session[:userid])                # Create a new provision workflow for this edit session
      rescue MiqException::MiqVmError => bang
        @no_wf_msg = _("Cannot create Request Info, error: ") << bang.message
      end
      if options[:wf]
        options[:wf].init_from_dialog(@options,session[:userid])                                 # Create a new provision workflow for this edit session
        #setting active tab to first visible tab
        options[:wf].get_dialog_order.each do |d|
          if options[:wf].get_dialog(d)[:display] == :show
            @options[:current_tab_key] = d
            break
          end
        end
        fld = options[:wf].kind_of?(MiqHostProvisionWorkflow) ? "tag_ids" : "vm_tags"
        @options["#{fld}".to_sym] = Array.new if @options["#{fld}".to_sym].nil?   #Initialize if came back nil from record
        build_tags_tree(options[:wf],@options["#{fld}".to_sym],false) if @miq_request.resource_type != "VmMigrateRequest"
        if !["MiqHostProvisionRequest", "VmMigrateRequest"].include?(@miq_request.resource_type)
          build_ous_tree(options[:wf],@options[:ldap_ous])
          @sb[:vm_os] = VmOrTemplate.find_by_id(@options[:src_vm_id][0]).platform if @options[:src_vm_id] && @options[:src_vm_id][0]
        end
        @options[:wf] = options[:wf]
      end
    else
      @options = @miq_request.options
      @options[:memory], @options[:mem_typ] = reconfigure_calculations(@options[:vm_memory]) if @options[:vm_memory]
      @force_no_grid_xml   = true
      @view, @pages = get_view(Vm, :view_suffix=>"VmReconfigureRequest", :where_clause=>["vms.id IN (?)",@miq_request.options[:src_ids]]) # Get the records (into a view) and the paginator
    end
    @temp[:user] = User.find_by_userid(@miq_request.stamped_by)
  end

  # Set form variables for provision request
  def prov_set_form_vars(req = nil)
    @edit ||= Hash.new
    session[:prov_options] = @options = nil     #Clearing out options that were set on show screen
    @edit[:req_id] = req ? req.id : nil                           # Save existing request record id, if passed in
    @edit[:key] = "prov_edit__#{@edit[:req_id] && @edit[:req_id] || "new"}"
    options = req ? req.get_options : Hash.new                    # Use existing request options, if passed in
    @edit[:new] = options unless @workflow_exists
    @edit[:org_controller] = params[:org_controller]  if params[:org_controller]          #request originated from controller
    @edit[:prov_option_types] = MiqRequest::MODEL_REQUEST_TYPES[@layout == "miq_request_vm" ? :Vm : :Host]
    if ["miq_template","service_template","vm"].include?(@edit[:org_controller])
      if params[:prov_type] && !req
        # only do this new requests
        @edit[:prov_type] =  @edit[:prov_option_types][params[:prov_type].to_sym]
        @edit[:prov_id] =  params[:prov_id]
        if params[:prov_type] == "migrate"
          @edit[:prov_type] = "VM Migrate"
          @edit[:new][:src_ids] = params[:prov_id]
          @edit[:wf] = VmMigrateWorkflow.new(@edit[:new],session[:userid])                        # Create a new provision workflow for this edit session
        else
          @edit[:prov_type] = "VM Provision"
          options = Hash.new
          if @edit[:org_controller] == "service_template"
            options[:service_template_request] = true
          else
            options[:src_vm_id] = @edit[:prov_id]
            options[:request_type] = params[:prov_type].to_sym
          end
          #setting class to MiqProvisionVmwareWorkflow for requests where src_vm_id is not already set, i.e catalogitem
          wf_type = !options[:src_vm_id].blank? ? MiqProvisionWorkflow.class_for_source(options[:src_vm_id]) : MiqProvisionVmwareWorkflow
          @edit[:wf] = wf_type.new(@edit[:new],session[:userid],options)                        # Create a new provision workflow for this edit session
        end
      else
        options = Hash.new
        if @edit[:org_controller] == "service_template"
          options[:service_template_request] = true
        end
        options[:initial_pass] = true if req.nil?
        #setting class to MiqProvisionVmwareWorkflow for requests where src_vm_id is not already set, i.e catalogitem
        src_vm_id = if @edit[:new][:src_vm_id] && !@edit[:new][:src_vm_id][0].blank?
          @edit[:new][:src_vm_id]
        elsif @src_vm_id || params[:src_vm_id]  # Set vm id if pre-prov chose one
          options[:src_vm_id] = [@src_vm_id || params[:src_vm_id].to_i]
        end

        options[:use_pre_dialog] = false if @workflow_exists

        if src_vm_id && !src_vm_id[0].blank?
          wf_type = MiqProvisionWorkflow.class_for_source(src_vm_id[0])
        else
          #handle copy button for host provisioning
          wf_type = @edit[:st_prov_type] ? MiqProvisionWorkflow.class_for_platform(@edit[:st_prov_type]) : MiqHostProvisionWorkflow
        end
        pre_prov_values = copy_hash(@edit[:wf].values) if @edit[:wf]
        begin
          @edit[:wf] = req && req.type == "VmMigrateRequest" ? VmMigrateWorkflow.new(@edit[:new],session[:userid]) : wf_type.new(@edit[:new],session[:userid], options)   # Create a new provision workflow for this edit session
        rescue MiqException::MiqVmError => bang
          #only add this message if showing a list of Catalog items, show screen already handles this
          @no_wf_msg = _("Cannot create Request Info, error: ") << bang.message
        end
        @edit[:prov_type] = req && req.request_type ? req.request_type_display : (req && req.type == "VmMigrateRequest" ? "VM Migrate" : "VM Provision")
      end
    else
      @edit[:prov_type] = "Host"
      if @edit[:new].empty?
        # only need to set this for new records
        @edit[:new][:src_host_ids] = Array.new
        if params[:prov_id].kind_of?(Array)
          #multiple hosts selected
          @edit[:new][:src_host_ids] = params[:prov_id]
        else
          @edit[:new][:src_host_ids].push(params[:prov_id])
        end
      end
      @edit[:wf] = MiqHostProvisionWorkflow.new(@edit[:new],session[:userid])                       # Create a new provision workflow for this edit session
    end

    if @edit[:wf]
      @edit[:wf].get_dialog_order.each do |d|
        if @edit[:wf].get_dialog(d)[:display] == :show
          @edit[:new][:current_tab_key] = d
          break
        end
      end
      @edit[:buttons] = @edit[:wf].get_buttons
      @edit[:wf].init_from_dialog(@edit[:new],session[:userid])                                 # Create a new provision workflow for this edit session
      @timezone_offset = get_timezone_offset
      if @edit[:new][:schedule_time]
        @edit[:new][:schedule_time] = format_timezone(@edit[:new][:schedule_time],Time.zone,"raw")
        @edit[:new][:start_date] = "#{@edit[:new][:schedule_time].month}/#{@edit[:new][:schedule_time].day}/#{@edit[:new][:schedule_time].year}" # Set the start date
        if params[:id]
          @edit[:new][:start_hour] = "#{@edit[:new][:schedule_time].hour}"
          @edit[:new][:start_min] = "#{@edit[:new][:schedule_time].min}"
        else
          @edit[:new][:start_hour] = "00"
          @edit[:new][:start_min] = "00"
        end
      end
      fld = @edit[:wf].kind_of?(MiqHostProvisionWorkflow) ? "tag_ids" : "vm_tags"
      @edit[:new]["#{fld}".to_sym] = Array.new if @edit[:new]["#{fld}".to_sym].nil?     #Initialize for new record
      @edit[:current] ||= Hash.new
      @edit[:current] = copy_hash(@edit[:new])
      # Give the model a change to modify the dialog based on the default settings
      #common grids
      @edit[:wf].refresh_field_values(@edit[:new],session[:userid])
      unless pre_prov_values.nil?
        @edit[:new] = @edit[:new].reject { |_k, v| v.nil? }
        @edit[:new] = @edit[:new].merge pre_prov_values.select { |k| !@edit[:new].keys.include? k }
      end
      @edit[:ds_sortdir] ||= "DESC"
      @edit[:ds_sortcol] ||= "free_space"
      @edit[:host_sortdir] ||= "ASC"
      @edit[:host_sortcol] ||= "name"
      build_host_grid(@edit[:wf].send("allowed_hosts"),@edit[:host_sortdir],@edit[:host_sortcol])
      build_ds_grid(@edit[:wf].send("allowed_storages"),@edit[:ds_sortdir],@edit[:ds_sortcol])
      if @edit[:wf].kind_of?(MiqProvisionWorkflow)
        @edit[:vm_sortdir] ||= "ASC"
        @edit[:vm_sortcol] ||= "name"
        @edit[:vc_sortdir] ||= "ASC"
        @edit[:vc_sortcol] ||= "name"
        @edit[:template_sortdir] ||= "ASC"
        @edit[:template_sortcol] ||= "name"
        build_vm_grid(@edit[:wf].send("allowed_templates"),@edit[:vm_sortdir],@edit[:vm_sortcol])
        build_tags_tree(@edit[:wf],@edit[:new][:vm_tags],true)
        build_ous_tree(@edit[:wf],@edit[:new][:ldap_ous])
        if @edit[:wf].supports_pxe?
          @edit[:pxe_img_sortdir] ||= "ASC"
          @edit[:pxe_img_sortcol] ||= "name"
          @edit[:windows_image_sortdir] ||= "ASC"
          @edit[:windows_image_sortcol] ||= "name"
          build_pxe_img_grid(@edit[:wf].send("allowed_images"),@edit[:pxe_img_sortdir],@edit[:pxe_img_sortcol])
          build_host_grid(@edit[:wf].send("allowed_hosts"),@edit[:host_sortdir],@edit[:host_sortcol])
          build_template_grid(@edit[:wf].send("allowed_customization_templates"),@edit[:template_sortdir],@edit[:template_sortcol])
        elsif @edit[:wf].supports_iso?
          @edit[:iso_img_sortdir] ||= "ASC"
          @edit[:iso_img_sortcol] ||= "name"
          build_iso_img_grid(@edit[:wf].send("allowed_iso_images"),@edit[:iso_img_sortdir],@edit[:iso_img_sortcol])
        else
          build_vc_grid(@edit[:wf].send("allowed_customization_specs"),@edit[:vc_sortdir],@edit[:vc_sortcol])
        end
      elsif @edit[:wf].kind_of?(VmMigrateWorkflow)
      else
        @edit[:pxe_img_sortdir] ||= "ASC"
        @edit[:pxe_img_sortcol] ||= "name"
        @edit[:iso_img_sortdir] ||= "ASC"
        @edit[:iso_img_sortcol] ||= "name"
        @edit[:windows_image_sortdir] ||= "ASC"
        @edit[:windows_image_sortcol] ||= "name"
        @edit[:template_sortdir] ||= "ASC"
        @edit[:template_sortcol] ||= "name"
        build_tags_tree(@edit[:wf],@edit[:new][:tag_ids],true)
        build_pxe_img_grid(@edit[:wf].send("allowed_images"),@edit[:pxe_img_sortdir],@edit[:pxe_img_sortcol])
        build_iso_img_grid(@edit[:wf].send("allowed_iso_images"),@edit[:iso_img_sortdir],@edit[:iso_img_sortcol])
        build_host_grid(@edit[:wf].send("allowed_hosts"),@edit[:host_sortdir],@edit[:host_sortcol])
        build_template_grid(@edit[:wf].send("allowed_customization_templates"),@edit[:template_sortdir],@edit[:template_sortcol])
      end
    else
      @edit[:current] ||= Hash.new
      @edit[:current] = copy_hash(@edit[:new])
    end
  end

  def build_ous_tree(wf,ldap_ous)
    dcs = wf.send("allowed_ous_tree")
    @curr_dc = nil
    # Build the default filters tree for the search views
    all_dcs = []                        # Array to hold all CIs
    dcs.each_with_index do |dc,i| # Go thru all of the Searches
      @curr_tag = dc[0]
      @ci_node = {
        :key         => dc[0],
        :title       => dc[0],
        :tooltip     => dc[0],
        :icon        => "folder.png",
        :cfmeNoClick => true,
        :addClass    => "cfme-bold-node",
        :expand      => true
      }
      @ci_kids = []
      dc[1].each_with_index do |ou,j|
        id = ou[1][:ou].join(",")
        id.gsub!(/,/,"_-_")         # Workaround for save/load openstates, replacing commas in ou array
        temp = {
          :key     => id,
          :tooltip => ou[0],
          :title   => ou[0],
          :icon    => "group.png"
        }
        if ldap_ous == ou[1][:ou]
          #expand selected nodes parents when editing existing record
          @expand_parent_nodes = id
          temp[:addClass] = "cfme-blue-bold-node"
        else
          temp[:addClass] = "cfme-no-cursor-node"
        end
        @ou_kids = []
        ou[1].each do |lvl1|
          if lvl1.kind_of?(Array) && lvl1[0] != :ou && lvl1[0] != :path
            kids = get_ou_kids(lvl1,ldap_ous)
            @ou_kids.push(kids) unless @ou_kids.include?(kids)
          end
        end
        temp[:children] = @ou_kids unless @ou_kids.blank?
        @ci_kids.push(temp) unless @ci_kids.include?(temp)
      end
      if i == dcs.length-1            # Adding last node
        @ci_node[:children] = @ci_kids unless @ci_kids.blank?
        all_dcs.push(@ci_node)
      end
    end
    unless all_dcs.blank?
      @temp[:ldap_ous_tree] = all_dcs.to_json  # Add ci node array to root of tree
    else
      @temp[:ldap_ous_tree] = nil
    end
    session[:tree_name] = "ldap_ous_tree"
  end

  def get_ou_kids(node,ldap_ous)
    id = node[1][:ou].join(",")
    id.gsub!(/,/,"_-_")       # Workaround for save/load openstates, replacing commas in ou array
    kids = {
      :key      => id,
      :title    => node[0],
      :tooltip  => node[0],
      :icon     => "group.png"
    }

    if ldap_ous == node[1][:ou]
      kids[:addClass] = "cfme-blue-bold-node"
      @expand_parent_nodes = id
    else
      kids[:addClass] = "cfme-no-cursor-node"
    end

    ou_kids = []
    node[1].each do |k|
      if k.kind_of?(Array) && k[0] != :ou && k[0] != :path
        ou = get_ou_kids(k,ldap_ous)
        ou_kids.push(ou) unless ou_kids.include?(ou)
      end
      kids[:children] = ou_kids unless ou_kids.blank?
    end
    kids
  end

  def build_tags_tree(wf,vm_tags,edit_mode)
    tags = wf.send("allowed_tags")
    fld = wf.kind_of?(MiqHostProvisionWorkflow) ? ":tag_ids" : "vm_tags"
    @curr_tag = nil
    # Build the default filters tree for the search views
    all_tags = []                          # Array to hold all CIs
    kids_checked = false
    tags.each_with_index do |t,i| # Go thru all of the Searches
      if @curr_tag.blank? || @curr_tag != t[:name]
        if @curr_tag != t[:name] && @ci_node
          @ci_node[:expand] = true if kids_checked
          kids_checked = false
          @ci_node[:children] = @ci_kids unless @ci_kids.blank?
          all_tags.push(@ci_node) unless @ci_kids.blank?
        end
        @curr_tag = t[:name]
        @ci_node = {}                       # Build the ci node
        @ci_node[:key] = t[:id].to_s
        @ci_node[:title] = t[:description]
        @ci_node[:title] += " *" if t[:single_value]
        @ci_node[:tooltip] = t[:description]
        @ci_node[:addClass] = "cfme-no-cursor-node"      # No cursor pointer
        @ci_node[:icon] = "folder.png"
        @ci_node[:hideCheckbox] = @ci_node[:cfmeNoClick] = true
        @ci_node[:addClass] = "cfme-bold-node"  # Show node as different
        @ci_kids = []
      end
      if !@curr_tag.blank? && @curr_tag == t[:name]
        t[:children].each do |c|
          temp = {}
          temp[:key] = c[0].to_s
          #only add cfme_parent_key for single value tags, need to use in JS onclick handler
          temp[:cfme_parent_key] = t[:id].to_s if t[:single_value]
          temp[:title] = temp[:tooltip] = c[1][:description]
          temp[:addClass] = "cfme-no-cursor-node"
          temp[:icon] = "tag.png"
          if edit_mode              #Don't show checkboxes/radio buttons in non-edit mode
            if vm_tags && vm_tags.include?(c[0].to_i)
              temp[:select] = true
              kids_checked = true
            else
              temp[:select] = false
            end
            if @edit && @edit[:current]["#{fld}".to_sym] != @edit[:new]["#{fld}".to_sym]
              #checking to see if id is in current but not in new, change them to blue OR if id is in current but deleted from new
              if (!@edit[:current]["#{fld}".to_sym].include?(c[0].to_i) && @edit[:new]["#{fld}".to_sym].include?(c[0].to_i)) ||
                  (!@edit[:new]["#{fld}".to_sym].include?(c[0].to_i) && @edit[:current]["#{fld}".to_sym].include?(c[0].to_i))
                temp[:addClass] = "cfme-blue-bold-node"
              end
            end
            @ci_kids.push(temp) unless @ci_kids.include?(temp)
          else
            temp[:hideCheckbox] = true
            @ci_kids.push(temp) unless @ci_kids.include?(temp) || !vm_tags.include?(c[0].to_i)
          end
        end
      end
      if i == tags.length-1           # Adding last node
        @ci_node[:expand] = true if kids_checked
        kids_checked = false
        @ci_node[:children] = @ci_kids unless @ci_kids.blank?
        all_tags.push(@ci_node) unless @ci_kids.blank?
      end
    end
    @temp[:all_tags_tree] = all_tags.to_json # Add ci node array to root of tree
    session[:tree] = "all_tags"
    session[:tree_name] = "all_tags_tree"
  end


end
