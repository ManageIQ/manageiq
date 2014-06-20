class CimInstanceController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter  :cleanup_action
  after_filter  :set_session_data

  private

  # Examples:
  #   In CimBaseStorageExtentController, button_name("tag") => cim_base_storage_extent_tag
  #   In OntapFileShareController, button_name("create_datastore") => ontap_file_share_create_datastore
  def button_name(suffix)
    "#{self.class.table_name}_#{suffix}"
  end

  def process_index
    redirect_to :action => 'show_list'
  end

  def process_button
    @edit = session[:edit]                          # Restore @edit for adv search box
    params[:display] = @display if ["host","vms","storages"].include?(@display) # Were we displaying vms/storages

    if params[:pressed].starts_with?("vm_") ||        # Handle buttons from sub-items screen
        params[:pressed].starts_with?("miq_template_") ||
        params[:pressed].starts_with?("guest_") ||
        params[:pressed].starts_with?("storage_") ||
        params[:pressed].starts_with?("host_")

      scanhosts if params[:pressed] == "host_scan"
      analyze_check_compliance_hosts if params[:pressed] == "host_analyze_check_compliance"
      check_compliance_hosts if params[:pressed] == "host_check_compliance"
      refreshhosts if params[:pressed] == "host_refresh"
      tag(Host) if params[:pressed] == "host_tag"
      assign_policies(Host) if params[:pressed] == "host_protect"
      deletehosts if params[:pressed] == "host_delete"
      comparemiq if params[:pressed] == "host_compare"
      edit_record  if params[:pressed] == "host_edit"

      scanstorage if params[:pressed] == "storage_scan"
      refreshstorage if params[:pressed] == "storage_refresh"
      tag(Storage) if params[:pressed] == "storage_tag"

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      # Handle Host power buttons
      if ["host_shutdown","host_reboot","host_standby","host_enter_maint_mode","host_exit_maint_mode",
          "host_start","host_stop","host_reset"].include?(params[:pressed])
        powerbutton_hosts(params[:pressed].split("_")[1..-1].join("_")) # Handle specific power button
      else
        process_vm_buttons(pfx)

        # Control transferred to another screen, so return
        return if ["host_tag", "#{pfx}_policy_sim", "host_scan", "host_refresh",
                   "host_protect","host_compare","#{pfx}_compare", "#{pfx}_tag",
                   "#{pfx}_retire","#{pfx}_protect","#{pfx}_ownership","#{pfx}_right_size",
                   "#{pfx}_refresh", "#{pfx}_reconfigure", "storage_tag"].include?(params[:pressed]) &&
                    @flash_array == nil

        if !["host_edit","#{pfx}_edit","#{pfx}_miq_request_new","#{pfx}_clone","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
          @refresh_div = "main_div"
          @refresh_partial = "layouts/gtl"
          show                                                        # Handle EMS buttons
        end
      end
    else
      tag(self.class.model) if params[:pressed] == button_name("tag")
      create_logical_disk if params[:pressed] == button_name("create_logical_disk")
      create_datastore if params[:pressed] == button_name("create_datastore")
      @refresh_div = "main_div" # Default div for button.rjs to refresh


      return if [
                  button_name("tag"),
                  button_name("create_logical_disk"),
                  button_name("create_datastore")
                ].include?(params[:pressed]) && @flash_array == nil # Sub screen showing, so return

      if !@flash_array && !@refresh_partial # if no button handler ran, show not implemented message
        add_flash(I18n.t("flash.button.not_implemented"), :error)
        @refresh_partial = "layouts/flash_msg"
        @refresh_div     = "flash_msg_div"
      elsif @flash_array && @lastaction == "show"
        @record = identify_record(params[:id])
        @refresh_partial = "layouts/flash_msg"
        @refresh_div     = "flash_msg_div"
      end
    end

    if params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new","#{pfx}_clone",
                                                "#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
      if @redirect_controller
        if ["#{pfx}_clone","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id, :prov_type=>@prov_type, :prov_id=>@prov_id
          end
        else
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id
          end
        end
      else
        render :update do |page|
          page.redirect_to :action=>@refresh_partial, :id=>@redirect_id
        end
      end
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render :update do |page|                    # Use RJS to update the display
          if @refresh_partial != nil
            if @refresh_div == "flash_msg_div"
              page.replace(@refresh_div, :partial=>@refresh_partial)
            else
              if ["vms","hosts","storages"].include?(@display)  # If displaying vms, action_url s/b show
                page << "miqReinitToolbar('center_tb');"
                page.replace_html("main_div", :partial=>"layouts/gtl", :locals=>{:action_url=>"show/#{@ems.id}"})
              else
                page.replace_html(@refresh_div, :partial=>@refresh_partial)
              end
            end
          end
        end
      end
    end

  end

  def process_show(associations = {})
    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype   = "config"

    @record = identify_record(params[:id])
    return if record_no_longer_exists?(@record)

    @gtl_url = "/#{self.class.table_name}/show/#{@record.id.to_s}?"

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@record)
      drop_breadcrumb( { :name => ui_lookup(:tables=>self.class.table_name), :url => "/#{self.class.table_name}/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb( { :name => @record.evm_display_name + " (Summary)",   :url => "/#{self.class.table_name}/show/#{@record.id}"} )
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)

    when "performance"
      @showtype = "performance"
      drop_breadcrumb( {:name=>"#{@record.evm_display_name} Capacity & Utilization", :url=>"/#{self.class.table_name}/show/#{@record.id}?display=#{@display}&refresh=n"} )
      perf_gen_init_options               # Intialize perf chart options, charts will be generated async

    else
      whitelisted_key = associations.keys.find { |key| key == @display }
      if whitelisted_key.present?
        model_name = whitelisted_key.singularize.classify.constantize
        drop_breadcrumb( {:name=>@record.evm_display_name+" (All #{ui_lookup(:tables => @display.singularize)})", :url=>"/#{self.class.table_name}/show/#{@record.id}?display=#{@display}"} )
        @view, @pages = get_view(model_name, :parent=>@record, :parent_method => associations[@display])  # Get the records (into a view) and the paginator
        @showtype = @display
      end
    end

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def get_session_data
    @title      = ui_lookup(:tables => self.class.table_name)
    @layout     = self.class.table_name
    prefix      = self.class.session_key_prefix
    @lastaction = session["#{prefix}_lastaction".to_sym]
    @showtype   = session["#{prefix}_showtype".to_sym]
    @display    = session["#{prefix}_display".to_sym]
  end

  def set_session_data
    prefix                                 = self.class.session_key_prefix
    session["#{prefix}_lastaction".to_sym] = @lastaction
    session["#{prefix}_showtype".to_sym]   = @showtype
    session["#{prefix}_display".to_sym]    = @display unless @display.nil?
  end

end
