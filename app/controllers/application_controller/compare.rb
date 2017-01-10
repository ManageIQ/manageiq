module ApplicationController::Compare
  extend ActiveSupport::Concern

  def get_compare_report(model)
    db = model.kind_of?(String) ? model.constantize : model
    MiqReport.find_by(:filename => "#{db.table_name}.yaml", :template_type => "compare")
  end

  def create_compare_view
    @sb[:miq_temp_params] = "all"
    # @sb[:miq_squashed] = false # added to control expand/collapse all

    rpt = get_compare_report(@sb[:compare_db])
    session[:miq_sections] = MiqCompare.sections(rpt)
    ids = session[:miq_selected].collect(&:to_i)
    @compare = MiqCompare.new({:ids     => ids,
                               :include => session[:miq_sections]},
                              rpt
                             )
    get_formatted_time("_model_", "compare")
    session[:compare_state] = {}
    @compare
  end

  # Return the xml version of the list view via Ajax
  def compare_grid_xml
    render :xml => session[:xml]
    session[:xml] = nil
  end

  # Compare multiple VMs
  def compare_miq(_db = nil)
    @compressed = session[:miq_compressed]
    @exists_mode = session[:miq_exists_mode]
    if @compare.nil? # == nil
      compare_init("compare")                                       # Init compare screen variables
    end
    case @sb[:compare_db]
    when "Vm"
      session[:db_title] = "VMs"
    when "Host"
      session[:db_title] = "Hosts"
    when "EmsCluster"
      session[:db_title] = "Clusters"
    when "MiqTemplate"
      session[:db_title] = "Templates"
    else
      session[:db_title] = "VMs"
    end
    drop_breadcrumb(:name => _("Compare %{name}") % {:name => ui_lookup(:model => @sb[:compare_db])},
                    :url  => "/#{session[:db_title].singularize.downcase}/compare_miq")
    @lastaction = "compare_miq"
    if params[:ppsetting]                                 # User selected new per page value
      @items_per_page = params[:ppsetting].to_i           # Set the new per page value
    end
    @compare = create_compare_view
    @sections_tree = TreeBuilderSections.new(:all_sections,
                                             :all_sections_tree,
                                             @sb,
                                             true,
                                             @compare,
                                             controller_name,
                                             current_tenant.name)
    compare_to_json(@compare)
    if params[:ppsetting] # Came in from per page setting
      replace_main_div({:partial => "layouts/compare"}, {:spinner_off => true})
    else
      if @explorer
        @refresh_partial = "layouts/compare"
      else
        @showtype = "compare"
        render :action => "show"
      end
    end
  end

  # Compare multiple VMs to show differences
  def compare_miq_same
    @sb[:miq_temp_params] = "same"
    compare_all_diff_same
  end

  # Compare multiple VMs to show all
  def compare_miq_all
    @sb[:miq_temp_params] = "all"
    compare_all_diff_same
  end

  def compare_squash
    @sb[:miq_squashed] = ! @sb[:miq_squashed]
    if @sb[:miq_squashed]
      img_src = "close"
    else
      img_src = "squashed-all-true"
    end
    render :update do |page|
      page << javascript_prologue
      asset = ActionController::Base.helpers.image_path("toolbars/#{img_src}.png")
      page << "$('#expand_collapse').prop('src', '#{asset}');"
    end
  end

  def compare_all_diff_same
    @compare = Marshal.load(session[:miq_compare])
    @compressed = session[:miq_compressed]
    @exists_mode = session[:miq_exists_mode]
    @compare.remove_id(params[:id].to_i) if @lastaction == "compare_remove"
    drop_breadcrumb(:name => _("Compare %{name}") % {:name => session[:db_title]},
                    :url  => "/#{session[:db_title].singularize.downcase}/compare_miq")
    @lastaction = "compare_miq"
    if params[:ppsetting]                                 # User selected new per page value
      @items_per_page = params[:ppsetting].to_i           # Set the new per page value
    end
    compare_to_json(@compare)
    render :update do |page|
      page << javascript_prologue
      if @sb[:miq_temp_params] == "different"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'compare_all');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'compare_all');"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'compare_same');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'compare_same');"
        page << "ManageIQ.toolbars.disableItem('#center_tb', 'compare_diff');"
        page << "ManageIQ.toolbars.markItem('#center_tb', 'compare_diff');"
      elsif @sb[:miq_temp_params] == "same"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'compare_all');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'compare_all');"
        page << "ManageIQ.toolbars.disableItem('#center_tb', 'compare_same');"
        page << "ManageIQ.toolbars.markItem('#center_tb', 'compare_same');"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'compare_diff');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'compare_diff');"
      else
        page << "ManageIQ.toolbars.disableItem('#center_tb', 'compare_all');"
        page << "ManageIQ.toolbars.markItem('#center_tb', 'compare_all');"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'compare_same');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'compare_same');"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'compare_diff');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'compare_diff');"
      end
      page.replace_html("main_div", :partial => "layouts/compare")  # Replace the main div area contents
      page << "miqSparkle(false);"
    end
  end

  # Compare multiple VMs to show same
  def compare_miq_differences
    @sb[:miq_temp_params] = "different"
    compare_all_diff_same
  end

  # User selected a new base VM
  def compare_choose_base
    @compare = Marshal.load(session[:miq_compare])
    @compressed = session[:miq_compressed]
    @exists_mode = session[:miq_exists_mode]
    @compare.set_base_record(params[:id].to_i) if @lastaction == "compare_miq"                      # Remove the VM from the vm compare
    compare_to_json(@compare)
    replace_main_div({:partial => "layouts/compare"}, {:spinner_off => true})
  end

  # Toggle compressed/expanded view
  def compare_compress
    @compare = Marshal.load(session[:miq_compare])
    @exists_mode = session[:miq_exists_mode]
    session[:miq_compressed] = !session[:miq_compressed]
    @compressed = session[:miq_compressed]
    compare_to_json(@compare)
    render :update do |page|
      page << javascript_prologue
      if @compressed
        page << "ManageIQ.toolbars.enableItem('#view_tb', 'compare_expanded');"
        page << "ManageIQ.toolbars.unmarkItem('#view_tb', 'compare_expanded');"
        page << "ManageIQ.toolbars.disableItem('#view_tb', 'compare_compressed');"
        page << "ManageIQ.toolbars.markItem('#view_tb', 'compare_compressed');"
      else
        page << "ManageIQ.toolbars.disableItem('#view_tb', 'compare_expanded');"
        page << "ManageIQ.toolbars.markItem('#view_tb', 'compare_expanded');"
        page << "ManageIQ.toolbars.enableItem('#view_tb', 'compare_compressed');"
        page << "ManageIQ.toolbars.unmarkItem('#view_tb', 'compare_compressed');"
      end
      page.replace_html("main_div", :partial => "layouts/compare")  # Replace the main div area contents
      page << "miqSparkle(false);"
    end
  end

  # Toggle exists/details view
  def compare_mode
    @keep_compare = true
    @compare = Marshal.load(session[:miq_compare])
    session[:miq_exists_mode] = !session[:miq_exists_mode]
    @exists_mode = session[:miq_exists_mode]
    compare_to_json(@compare)
    render :update do |page|
      page << javascript_prologue
      if @exists_mode
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'comparemode_details');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'comparemode_details');"
        page << "ManageIQ.toolbars.disableItem('#center_tb', 'comparemode_exists');"
        page << "ManageIQ.toolbars.markItem('#center_tb', 'comparemode_exists');"
      else
        page << "ManageIQ.toolbars.disableItem('#center_tb', 'comparemode_details');"
        page << "ManageIQ.toolbars.markItem('#center_tb', 'comparemode_details');"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'comparemode_exists');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'comparemode_exists');"
      end
      page.replace_html("main_div", :partial => "layouts/compare")  # Replace the main div area contents
      page << "miqSparkle(false);"
    end
  end

  def compare_set_state
    @keep_compare = true
    session[:compare_state] ||= {}
    if !session[:compare_state].include?(params["rowId"])
      session[:compare_state][params["rowId"]] = params["state"]
    elsif session[:compare_state].include?(params["rowId"]) && params["state"].to_i == -1
      session[:compare_state].delete(params["rowId"])
    end
    render :update do |page|
      page << javascript_prologue
      page << "miqSparkle(false);"
      # head :ok
    end
  end

  # User checked/unchecked a compare section
  def compare_checked
    section_checked(:compare)
  end

  # Remove one of the VMs from the @compare object
  def compare_remove
    @compare = Marshal.load(session[:miq_compare])
    @compressed = session[:miq_compressed]
    @exists_mode = session[:miq_exists_mode]
    @compare.remove_record(params[:id].to_i) if @lastaction == "compare_miq"                      # Remove the VM from the vm compare
    compare_to_json(@compare)
    replace_main_div({:partial => "layouts/compare"}, {:spinner_off => true})
  end

  # Send the current compare data in text format
  def compare_to_txt
    @compare = Marshal.load(session[:miq_compare])
    rpt = create_compare_report
    filename = "compare_report_" + format_timezone(Time.now, Time.zone, "fname")
    disable_client_cache
    send_data(rpt.to_text, :filename => "#{filename}.txt")
  end

  # Send the current compare data in CSV format
  def compare_to_csv
    @compare = Marshal.load(session[:miq_compare])
    rpt = create_compare_report(true)
    filename = "compare_report_" + format_timezone(Time.now, Time.zone, "fname")
    disable_client_cache
    send_data(rpt.to_csv, :filename => "#{filename}.csv")
  end

  # Send the current compare data in PDF format
  def compare_to_pdf
    @compare = Marshal.load(session[:miq_compare])
    rpt = create_compare_report
    render_pdf(rpt)
  end

  def column_names_for_compare_or_drift_report(mode)
    # Collect the column names from the @compare object
    column_names = ["Section", "Entry", "Sub-Entry"]

    if mode == :compare
      column_names << @compare.records[0].name
      @compare.records[1..-1].each do |r|
        column_names.push(r["name"]) unless r["id"] == @compare.records[0]["id"]
      end
    else
      @compare.ids.each do |r|
        t = r.getgm
        column_names.push(t.strftime("%m/%d/%y") + " " + t.strftime("%H:%M ") + t.zone)
      end
    end

    column_names
  end
  private :column_names_for_compare_or_drift_report

  def prepare_data_for_compare_or_drift_report(mode, csv)
    sb_key = (mode == :compare) ? :miq_temp_params : :miq_drift_params

    # Collect the data from the @compare object
    @data = []
    @compare.master_list.each_slice(3) do |section, records, fields| # section is a symbol, records and fields are arrays
      if @compare.include[section[:name]][:checked]     # Only grab the sections that are checked
        if !records.nil? && !records.empty?
          records.each do |attr|
            cols = [section[:header].to_s, attr, ""]      # Start the row with section and attribute names
            # Grab the base VM's value
            if records.include?(attr)
              bas = "Found"
            else
              bas = "Missing"
            end
            cols.push(bas)

            # Grab the other VMs values
            # @compare.results.each do |r|         # Go thru each of the VMs
            @compare.ids.each_with_index do |r, idx|         # Go thru each of the VMs
              # unless r[0] == @compare.records[0]["id"] # Skip the base VM
              unless idx == 0 # Skip the base VM
                if @compare.results[r][section[:name]].include?(attr)                         # Set the report value
                  rval = "Found"
                  val = "Found"
                else
                  rval = "Missing"
                  val = "Missing"
                end
                if mode == :compare
                  rval = "* " + rval if bas.to_s != val.to_s      # Mark the ones that don't match the base
                else
                  rval = "* " + rval if @compare.results[r][section[:name]][attr] && !@compare.results[r][section[:name]][attr][:_match_]     # Mark the ones that don't match the base
                end
                cols.push(rval)
              end
            end
            build_download_rpt(cols, csv, @sb[sb_key])                       # Add the row to the data array
          end
        end

        if records.nil? && !fields.nil? && !fields.empty?
          fields.each do |attr|
            cols = [section[:header].to_s, attr[:header].to_s, ""]     # Start the row with section and attribute names
            @compare.ids.each_with_index do |r, idx|         # Go thru each of the VMs
              if !@compare.results[r][section[:name]].nil?
                rval = @compare.results[r][section[:name]][attr[:name]][:_value_]
              else
                rval = "(missing)"
              end
              unless idx == 0                             # If not generating CSV
                if mode == :compare
                  rval = "* " + rval.to_s if @compare.results[@compare.ids[0]][section[:name]][attr[:name]][:_value_].to_s != rval.to_s     # Mark the ones that don't match the base
                else
                  rval = "* " + rval.to_s unless @compare.results[@compare.ids[idx]][section[:name]][attr[:name]][:_match_]      # Mark the ones that don't match the base
                end
              end
              cols.push(rval)
            end
            build_download_rpt(cols, csv, @sb[sb_key])                       # Add the row to the data array
          end
        end

        if !records.nil? && !fields.nil? && !fields.empty?
          records.each do |level2|
            fields.each do |attr|
              cols = [section[:header].to_s, level2, attr[:header]]     # Start the row with section and attribute names
              @compare.ids.each_with_index do |r, idx|         # Go thru each of the VMs
                if !@compare.results[r][section[:name]][level2].nil?
                  rval = @compare.results[r][section[:name]][level2][attr[:name]][:_value_].to_s
                else
                  rval = "(missing)"
                end
                if idx > 0
                  if mode == :compare
                    rval = "* " + rval.to_s  if !@compare.results[@compare.ids[0]][section[:name]][level2].nil? && @compare.results[@compare.ids[0]][section[:name]][level2][attr[:name]][:_value_].to_s != rval.to_s     # Mark the ones that don't match the base
                    rval = "* " + rval.to_s  if @compare.results[@compare.ids[0]][section[:name]][level2].nil? && rval.to_s != "(missing)"      # Mark the ones that don't match the base
                  else
                    # Mark the ones that don't match the prior VM
                    rval = "* " + rval if @compare.results[r][section[:name]][level2] && @compare.results[r][section[:name]][level2][attr[:name]] && !@compare.results[r][section[:name]][level2][attr[:name]][:_match_]
                  end
                end
                cols.push(rval)
              end
              build_download_rpt(cols, csv, @sb[sb_key])                       # Add the row to the data array
            end
          end
        end

        unless csv                              # Don't generate % lines for csv output
          if mode == :compare
            cols = ["#{section[:header]} - % Match:", "", "", "Base"]    # Generate % line, first 3 cols
          else
            cols = ["#{section[:header]} - Changed:", "", ""]            # Generate % line, first 3 cols
          end

          @compare.results.each do |r|            # Go thru each of the VMs
            if mode == :compare
              next if r[0] == @compare.records[0]["id"] # Skip the base VM
              cols.push(r[1][section[:name]][:_match_].to_s + "%")  # Grab the % value for this attr for this VM
            else
              if r[1][section[:name]][:_match_]  # Does it match?
                cols.push("")                     # Yes, push a blank string
              else
                cols.push("*")                    # No, mark it with an *
              end
            end
          end
          build_download_rpt(cols, csv, "all")                        # Add the row to the data array
        end
      end
    end # end of all includes/sections
  end
  private :prepare_data_for_compare_or_drift_report


  # Create an MIQ_Report object from a compare object
  def create_compare_or_drift_report(mode, csv = false)
    column_names  = column_names_for_compare_or_drift_report(mode)
    prepare_data_for_compare_or_drift_report(mode, csv) # fills @data

    rpt           = MiqReport.new
    rpt.table     = Ruport::Data::Table.new(:data => @data, :column_names => column_names)
    rpt.cols      = column_names
    rpt.col_order = column_names
    rpt.headers   = column_names
    rpt.sortby    = [column_names[0]]      # Set sortby to the first column

    if mode == :compare
      rpt.db = "<compare>"            # Set special db setting for report formatter
      rpt.title = _("%{name} Compare Report (* = Value does not match base)") %
                    {:name => ui_lookup(:model => @sb[:compare_db])}
    else
      rpt.db = "<drift>"            # Set special db setting for report formatter
      rpt.title = _("%{name} '%{vm_name}' Drift Report") % {:name    => ui_lookup(:model => @sb[:compare_db]),
                                                            :vm_name => @sb[:miq_vm_name]}
    end

    rpt
  end
  private :create_compare_or_drift_report

  # Create an MIQ_Report object from a compare object
  def create_compare_report(csv = false)
    create_compare_or_drift_report(:compare, csv)
  end

  # Create an MIQ_Report object from a compare object
  def create_drift_report(csv = false)
    create_compare_or_drift_report(:drift, csv)
  end

  def build_download_rpt(cols, csv, typ)
    if typ.nil? || typ == "all"
      if csv # If generating CSV, remove * from data
        cols.each_with_index do |c, i|
          if c.to_s.starts_with?("* ")
            cols[i].gsub!(/\*\s/, "")
          end
        end
      end
      @data.push(cols)                        # Add the row to the data array
    elsif typ == "same"
      same = true
      cols.each_with_index do |c, i|
        if c.to_s.starts_with?("* ")
          cols[i].gsub!(/\*\s/, "") if csv # If generating CSV
          same = false
        end
      end
      @data.push(cols)  if same                     # Add the row to the data array
    elsif typ == "different"
      same = true
      cols.each_with_index do |c, i|
        if c.to_s.starts_with?("* ")
          cols[i].gsub!(/\*\s/, "") if csv # If generating CSV
          same = false
        end
      end
      @data.push(cols)  unless same                      # Add the row to the data array
    end
  end

  def identify_obj
    @drift_obj = nil
    begin
      db = @sb[:compare_db].constantize
      if @sb[:compare_db] == "Host"
        @record = @host = @drift_obj = find_by_id_filtered(db, params[:id])
      elsif @sb[:compare_db] == "MiqTemplate"
        @record = @miq_templates = @drift_obj = find_by_id_filtered(db, params[:id])
      elsif @sb[:compare_db] == "Vm"
        @record = @vm = @drift_obj = find_by_id_filtered(db, params[:id])
      elsif @sb[:compare_db] == "EmsCluster"
        @record = @ems_cluster = @drift_obj = find_by_id_filtered(db, params[:id])
      else
        @record = @drift_obj = find_by_id_filtered(db, params[:id])
      end
    rescue ActiveRecord::RecordNotFound
      return
    end
  end

  def create_drift_view
    @sb[:miq_drift_params] = "all"
    compare_init("drift")                                     # Init compare screen variables
    identify_obj

    rpt = get_compare_report(@sb[:compare_db])
    session[:miq_sections] = MiqCompare.sections(rpt)
    @compare ||= MiqCompare.new({:id         => @drift_obj.id.to_i,            # Create the compare object
                                 :mode       => :drift,
                                 :timestamps => session[:timestamps],
                                 :include    => session[:miq_sections]
                        },
                                rpt
                               )
    get_formatted_time("_model_", "drift")
    session[:compare_state] = {}
    @compare
  end

  def get_formatted_time(section, typ = "compare")
    @compare.results.each do |vm|
      vm[1][section.to_sym].each do |s|
        if typ == "compare"
          @compare.master_list.each_slice(3) do |sections, records, _fields| # section is a symbol, records and fields are arrays
            if sections[:name].to_s == section.to_s
              if !records.blank?
                if s[1].kind_of?(Hash)
                  s[1].each do |f|
                    if f[1].kind_of?(Hash) && f[1].key?(:_value_) && f[1][:_value_].kind_of?(Time) && !f[1][:_value_].blank? && f[1][:_value_] != "" && f[1][:_value_] != MiqCompare::EMPTY
                      f[1][:_value_] = format_timezone(f[1][:_value_], Time.zone, "view")
                    end
                  end
                end
              else
                if s[1].kind_of?(Hash) && s[1].key?(:_value_) && s[1][:_value_].kind_of?(Time) && !s[1][:_value_].blank? && s[1][:_value_] != "" && s[1][:_value_] != MiqCompare::EMPTY
                  s[1][:_value_] = format_timezone(s[1][:_value_], Time.zone, "view")
                end
              end
            end
          end
        else
          @compare.master_list.each_slice(3) do |sections, records, _fields| # section is a symbol, records and fields are arrays
            if sections[:name].to_s == section.to_s
              if !records.blank?
                if s[1].kind_of?(Hash)
                  s[1].each do |f|
                    if DRIFT_TIME_COLUMNS.include?(f[0].to_s) && f[1].kind_of?(Hash) && f[1].key?(:_value_) && !f[1][:_value_].blank? && f[1][:_value_] != "" && f[1][:_value_] != MiqCompare::EMPTY
                      f[1][:_value_] = format_timezone(f[1][:_value_], Time.zone, "view")
                    end
                  end
                end
              else
                if DRIFT_TIME_COLUMNS.include?(s[0].to_s) && s[1].kind_of?(Hash) && s[1].key?(:_value_) && !s[1][:_value_].blank? && s[1][:_value_] != "" && s[1][:_value_] != MiqCompare::EMPTY
                  s[1][:_value_] = format_timezone(s[1][:_value_], Time.zone, "view")
                end
              end
            end
          end
        end
      end
    end
  end

  # Show drift analysis for multiple VM scans
  def drift
    @lastaction = "drift"
    @compare = create_drift_view
    @sections_tree = TreeBuilderSections.new(:all_sections,
                                             :all_sections_tree,
                                             @sb,
                                             true,
                                             @compare,
                                             controller_name,
                                             current_tenant.name)
    drift_to_json(@compare)
    drop_breadcrumb(:name => _("'%{name}' Drift Analysis") % {:name => @drift_obj.name},
                    :url  => "/#{@sb[:compare_db].downcase}/drift")
    @sb[:miq_vm_name] = @drift_obj.name
    if params[:ppsetting] # Came in from per page setting
      replace_main_div :partial => "layouts/compare", :id => @drift_obj.id
    else
      @showtype = "drift"
      if @explorer
        @refresh_partial = "layouts/compare"
      else
        render :action => "show", :id => @drift_obj.id
      end
    end
  end

  # Return the xml version of the list view via Ajax
  def drift_grid_xml
    render :xml => session[:xml]
    session[:xml] = nil
  end

  def drift_all_same_dff
    @compare = Marshal.load(session[:miq_compare])
    @compressed = session[:miq_compressed]
    @exists_mode = session[:miq_exists_mode]
    identify_obj

    drift_to_json(@compare)
    drop_breadcrumb(:name => _("'%{name}' Drift Analysis") % {:name => @sb[:miq_vm_name]},
                    :url  => "/#{@sb[:compare_db].downcase}/drift")
    @lastaction = "drift"
    @showtype = "drift"
    render :update do |page|
      page << javascript_prologue
      if @sb[:miq_drift_params] == "different"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'drift_all');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'drift_all');"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'drift_same');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'drift_same');"
        page << "ManageIQ.toolbars.disableItem('#center_tb', 'drift_diff');"
        page << "ManageIQ.toolbars.markItem('#center_tb', 'drift_diff');"
      elsif @sb[:miq_drift_params] == "same"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'drift_all');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'drift_all');"
        page << "ManageIQ.toolbars.disableItem('#center_tb', 'drift_same');"
        page << "ManageIQ.toolbars.markItem('#center_tb', 'drift_same');"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'drift_diff');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'drift_diff');"
      else
        page << "ManageIQ.toolbars.disableItem('#center_tb', 'drift_all');"
        page << "ManageIQ.toolbars.markItem('#center_tb', 'drift_all');"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'drift_diff');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'drift_diff');"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'drift_same');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'drift_same');"
      end
      page.replace_html("main_div", :partial => "layouts/compare") # Replace the main div area contents
      page << "miqSparkle(false);"
    end
  end

  def drift_all
    @sb[:miq_drift_params] = "all"
    drift_all_same_dff
  end

  def drift_differences
    @sb[:miq_drift_params] = "different"
    drift_all_same_dff
  end

  def drift_same
    @sb[:miq_drift_params] = "same"
    drift_all_same_dff
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def sections_field_changed
    @keep_compare = true
    if params[:check] == "drift"
      drift_checked
    elsif params[:check] == "compare_miq"
      compare_checked
    else
      set_checked_sections
      render :update do |page|
        page << javascript_prologue
        page << "miqSparkle(false);"
        # head :ok
      end
    end
  end

  def set_checked_sections
    if params[:all_checked]
      session[:selected_sections] = []
      params[:all_checked].each do |a|
        s = a.split(':')
        if s.length > 1
          session[:selected_sections].push(s[1])
        end
      end
    end
  end

  def drift_checked
    section_checked(:drift)
  end

  # Toggle exists/details view
  def drift_mode
    @compare = Marshal.load(session[:miq_compare])
    identify_obj
    session[:miq_exists_mode] = !session[:miq_exists_mode]
    @exists_mode = session[:miq_exists_mode]
    drift_to_json(@compare)
    render :update do |page|
      page << javascript_prologue
      if @exists_mode
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'driftmode_details');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'driftmode_details');"
        page << "ManageIQ.toolbars.disableItem('#center_tb', 'driftmode_exists');"
        page << "ManageIQ.toolbars.markItem('#center_tb', 'driftmode_exists');"
      else
        page << "ManageIQ.toolbars.disableItem('#center_tb', 'driftmode_details');"
        page << "ManageIQ.toolbars.markItem('#center_tb', 'driftmode_details');"
        page << "ManageIQ.toolbars.enableItem('#center_tb', 'driftmode_exists');"
        page << "ManageIQ.toolbars.unmarkItem('#center_tb', 'driftmode_exists');"
      end
      page.replace_html("main_div", :partial => "layouts/compare") # Replace the main div area contents
      page << "miqSparkle(false);"
    end
  end

  # Toggle drift compressed/expanded view
  def drift_compress
    @compare = Marshal.load(session[:miq_compare])
    session[:miq_compressed] = !session[:miq_compressed]
    @compressed = session[:miq_compressed]
    drift_to_json(@compare)
    render :update do |page|
      page << javascript_prologue
      if @compressed
        page << "ManageIQ.toolbars.enableItem('#view_tb', 'drift_expanded');"
        page << "ManageIQ.toolbars.unmarkItem('#view_tb', 'drift_expanded');"
        page << "ManageIQ.toolbars.disableItem('#view_tb', 'drift_compressed');"
        page << "ManageIQ.toolbars.markItem('#view_tb', 'drift_compressed');"
      else
        page << "ManageIQ.toolbars.disableItem('#view_tb', 'drift_expanded');"
        page << "ManageIQ.toolbars.markItem('#view_tb', 'drift_expanded');"
        page << "ManageIQ.toolbars.enableItem('#view_tb', 'drift_compressed');"
        page << "ManageIQ.toolbars.unmarkItem('#view_tb', 'drift_compressed');"
      end
      page.replace_html("main_div", :partial => "layouts/compare") # Replace the main div area contents
      page << "miqSparkle(false);"
    end
  end

  # Send the current drift data in text format
  def drift_to_txt
    @compare = Marshal.load(session[:miq_compare])
    rpt = create_drift_report
    filename = "drift_report_" + format_timezone(Time.now, Time.zone, "fname")
    disable_client_cache
    send_data(rpt.to_text, :filename => "#{filename}.txt")
  end

  # Send the current drift data in CSV format
  def drift_to_csv
    @compare = Marshal.load(session[:miq_compare])
    rpt = create_drift_report(true)
    filename = "drift_report_" + format_timezone(Time.now, Time.zone, "fname")
    disable_client_cache
    send_data(rpt.to_csv, :filename => "#{filename}.csv")
  end

  # Send the current drift data in PDF format
  def drift_to_pdf
    @compare = Marshal.load(session[:miq_compare])
    rpt = create_drift_report
    render_pdf(rpt)
  end

  def drift_history
    @sb[:compare_db] = compare_db(controller_name)
    identify_obj
    @timestamps = @drift_obj.drift_state_timestamps
    session[:timestamps] = @timestamps
    @showtype = "drift_history"
    drop_breadcrumb(:name => _("Drift History"), :url => "/#{controller_name}/drift_history/#{@drift_obj.id}")
    @lastaction = "drift_history"
    @display = "main"
    @button_group = "common_drift"
    if @explorer || request.xml_http_request? # Is this an Ajax request?
      @sb[:action] = params[:action]
      @refresh_partial = "vm_common/#{@showtype}"
      replace_right_cell
    else
      render :action => 'show'
    end
  end

  ##### End of compare & Drift methods

  private ############################

  ### Start of compare & drift related private methods

  # Initialize the VM compare array
  def compare_init(mode)
    @compare = nil                                                            # Clear the compare array to have it rebuilt
    @base = nil                                                                 # Clear the base comparison VM
    if mode == "compare"
      session[:miq_compressed]  = (@settings[:views][:compare] == "compressed")
      session[:miq_exists_mode] = (@settings[:views][:compare_mode] == "exists")
    else
      session[:miq_compressed]  = (@settings[:views][:drift] == "compressed")
      session[:miq_exists_mode] = (@settings[:views][:drift_mode] == "exists")
    end
    @compressed = session[:miq_compressed]
    @exists_mode = session[:miq_exists_mode]
  end

  # Set a given VM id as the base vm for compare
  def compare_set_base(baseid)
    @compare.results[1..-1].each do |c|
      if c[:object].id == baseid
        @base = c
        break
      end
    end

    compare_matches                             # Go calc match %s against the new base
  end

  # Calculate the value matches in each compare section
  def compare_matches
    @compare.results.each_with_index do |r, idx|                            # Go thru each VM result
      if idx != 0
        all_total = 0; all_matches = 0
        session[:miq_sections].each do |s|                                        # Go thru each section
          section = s[:name]
          if s[:added] == true                                                        # Only if section has data
            count = 0
            r[:results][s[:name]].each_with_index do |val, val_idx|         # Go thru each value
              count += 1 if val == @base[:results][s[:name]][val_idx]   # count matches between the value and the base value
            end
            if r[:results][s[:name]].length > 0
              r[:results][s[:name] + "_match"] = (count * 100) / r[:results][s[:name]].length # Set the percent of matches for the VM to the base
              if s[:checked] == true                                                  # Only if section is currently checked
                all_matches += count                                                # Add count to the total matches
                all_total += r[:results][s[:name]].length                       # Add total to the grand total
              end
            else
              r[:results][s[:name] + "_match"] = 0
            end
          end
        end
        r[:results]["all_match"] = all_total == 0 ? 0 : all_matches * 100 / all_total # Calculate the total matches percent
      end
    end
  end

  # Calculate the value matches in each drift section
  def drift_matches
    @compare.results.each_with_index do |r, idx|                            # Go thru each VM result
      if idx > 1                                                                            # Skip master list and first timestamp
        all_match = true
        prev = ""
        session[:miq_sections].each do |s|                                        # Go thru each section
          section = s[:name]
          match = true
          if s[:added] == true                                                        # Only if section has data
            r[:results][s[:name]].each_with_index do |val, val_idx|         # Go thru each value
              if val != @compare.results[idx - 1][:results][s[:name]][val_idx]  # Compare to previous timestamp entry
                match = false                                                         # Doesn't match, set it and
                break                                                                     #   move on to the next section
              end
            end
            r[:results][s[:name] + "_match"] = match                      # Set section match = true or false
            if s[:checked] == true                                                  # Only if section is currently checked
              all_match = match && all_match                                  # Set all_match
            end
          end
        end
        r[:results]["all_match"] = all_match                                    # Set all match value in the object
      end
    end
  end
  ####### End of compare & drift related methods

  # Compare selected VMs
  def comparemiq
    assert_privileges(params[:pressed])
    vms = []
    if !session[:checked_items].nil? && @lastaction == "set_checked_items"
      vms = session[:checked_items]
    else
      vms = find_checked_items
    end

    case request.parameters["controller"].downcase
    when "ems_cluster"
      title = _("Clusters")
    when "vm"
      title = _("Virtual Machines")
    when "miq_template"
      title = _("VM Templates")
    else
      title = request.parameters["controller"].pluralize.titleize
    end
    if vms.length < 2
      add_flash(_("At least 2 %{model} must be selected for Compare") % {:model => title}, :error)
      if @layout == "vm" # In vm controller, refresh show_list, else let the other controller handle it
        show_list
        @refresh_partial = "layouts/gtl"
      end
    elsif vms.length > 32
      add_flash(_("No more than 32 %{model} can be selected for Compare") % {:model => title}, :error)
      if @layout == "vm" # In vm controller, refresh show_list, else let the other controller handle it
        show_list
        @refresh_partial = "layouts/gtl"
      end
    else
      session[:miq_selected] = vms        # save the selected vms array for the redirect to compare_miq
      if params[:pressed]
        model, = pressed2model_action(params[:pressed])
        @sb[:compare_db] = compare_db(model)
      end
      if @explorer
        compare_miq(@sb[:compare_db])
      else
        javascript_redirect :action => 'compare_miq' # redirect to build the compare screen
      end
    end
  end
  alias_method :image_compare, :comparemiq
  alias_method :instance_compare, :comparemiq
  alias_method :vm_compare, :comparemiq
  alias_method :miq_template_compare, :comparemiq

  def compare_db(kls)
    case kls
    when "host"
      "Host"
    when "ems_cluster"
      "EmsCluster"
    when "miq_template"
      "MiqTemplate"
    else
      "VmOrTemplate"
    end
  end

  # Show drift
  def drift_analysis
    assert_privileges("common_drift")
    controller_name = @sb[:compare_db].underscore
    identify_obj
    tss = find_checked_items                                        # Get the indexes of the checked timestamps
    if tss.length < 2
      add_flash(_("At least 2 Analyses must be selected for Drift"), :error)
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
    elsif tss.length > 10
      add_flash(_("No more than 10 Analyses can be selected for Drift"), :error)
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
    else
      timestamps = []
      session[:timestamps].each_with_index do |ts, idx|
        timestamps.push(ts) if tss.include?(idx.to_s)
      end
      session[:timestamps] = timestamps
      if @explorer
        drift
      else
        javascript_redirect :controller => controller_name, :action => 'drift', :id => @drift_obj.id
      end
    end
  end
  alias_method :common_drift, :drift_analysis

  def section_checked(mode)
    @compare = Marshal.load(session[:miq_compare])
    @compressed = session[:miq_compressed]
    @exists_mode = session[:miq_exists_mode]
    if session[:selected_sections]
      session[:miq_sections].each do |section|              # Find the section
        if session[:selected_sections].include?(section[0].to_s)
          @compare.add_section(section[0])
          get_formatted_time(section[0], "compare")
        else
          @compare.remove_section(section[0])
        end
      end
    end
    send("#{mode}_to_json", @compare)
    replace_main_div({:partial => "layouts/compare"}, {:spinner_off => true})
  end

  # Build the header row of the compare grid xml
  def drift_add_header(view)
    row = []
    rowtemp = {
      :id    => "col0",
      :name  => "",
      :field => "col0",
      :width => 220
    }
    row.push(rowtemp)

    view.ids.each_with_index do |h, i|
      txt = format_timezone(h, Time.zone, "compare_hdr")
      rowtemp = {
        :id       => "col#{i + 1}",
        :field    => "col#{i + 1}",
        :width    => @compressed ? 40 : 150,
        :cssClass => "cell-effort-driven",
        :name     => @compressed ? "<span class='rotated-text'>#{txt}</span>" : txt
      }
      row.push(rowtemp)
    end
    @cols = row
  end

  # Build the total row of the compare grid xml
  def drift_add_total(view)
    row = {
      :col0  => "<span class='cell-effort-driven cell-plain'>" + _("All Sections") + "</span>",
      :id    => "id_#{@rows.length}",
      :total => true
    }
    view.ids.each_with_index do |_id, idx|
      if idx == 0
        row.merge!(drift_add_same_image(idx, _("Same as previous")))
      else
        if view.results[view.ids[idx]][:_match_] == 100
          row.merge!(drift_add_same_image(idx, _("Same as previous")))
        else
          row.merge!(drift_add_diff_image(idx, _("Changed from previous")))
        end
      end
    end
    @rows << row
  end

  # Build a section row for the compare grid xml
  def drift_add_section(view, section, records, fields)
    cell_text = section[:header]
    if records.nil? # Show records count if not nil
      cell_text += " (#{fields.length})"
    else                # Show fields count
      cell_text += " (#{records.length})"
    end
    row = {
      :col0       => cell_text,
      :id         => "id_#{@rows.length}",
      :indent     => 0,
      :parent     => nil,
      :section    => true,
      :exp_id     => section[:name].to_s,
      :_collapsed => collapsed_state(section[:name].to_s)
    }
    row.merge!(drift_section_data_cols(view, section))
    @section_parent_id = @rows.length
    @rows << row
  end

  def drift_section_data_cols(view, section)
    row = {}
    view.ids.each_with_index do |id, idx|
      if idx == 0
        row.merge!(drift_add_same_image(idx, _("Starting values")))
      else
        match_condition = view.results[id][section[:name]][:_match_]
        match_condition = view.results[id][section[:name]][:_match_exists_] if @exists_mode

        if match_condition == 100
          row.merge!(drift_add_same_image(idx, _("Same as previous")))
        else
          row.merge!(drift_add_diff_image(idx, _("Changed from previous")))
        end
      end
    end
    row
  end

  # Build a record row for the compare grid xml
  def drift_add_record(view, section, record, ridx)
    @same = true
    row = {
      :col0       => record,
      :id         => "id_#{@rows.length}",
      :indent     => 1,
      :parent     => @section_parent_id,
      :record     => true,
      :exp_id     => "#{section[:name]}_#{ridx}",
      :_collapsed => collapsed_state("#{section[:name]}_#{ridx}")
    }
    row.merge!(drift_record_data_cols(view, section, record))

    @record_parent_id = @rows.length
    @rows << row
  end

  def drift_record_data_cols(view, section, record)
    row = {}
    basval = ""                                              # Init base value
    match = 0
    view.ids.each_with_index do |id, idx|                    # Go thru all of the objects
      val = view.results[id][section[:name]].include?(record) ? "Found" : "Missing" # Get the value for current object
      match = view.results[id][section[:name]][record][:_match_] if view.results[id][section[:name]][record]
      if idx == 0                                            # On the base?
        row.merge!(drift_add_same_image(idx, val))
      else                                                   # On another object
        if @compressed  # Compressed, just check if it matches base
          row.merge!(drift_record_compressed(idx, match, val, basval))
        else
          row.merge!(drift_record_expanded(idx, match, val, basval))
        end
      end
      basval = val                                          # Save this record's val as the new base val
    end
    row
  end

  def drift_record_compressed(idx, match, val, basval)
    row = {}
    if val == basval && match == 100
      row.merge!(drift_add_same_image(idx, val))
    else
      @same = false
      row.merge!(drift_add_diff_image(idx, val))
    end
    row
  end

  def drift_record_expanded(idx, match, val, basval)
    row = {}
    if !@exists_mode
      row.merge!(drift_record_nonexistmode(idx, match, val, basval))
    else
      row.merge!(drift_record_existmode(idx, val, basval))
    end
    row
  end

  def drift_record_nonexistmode(idx, match, val, basval)
    row = {}
    if val == "Found"                                             # This object has the record
      if basval == "Found" && match == 100
        row.merge!(drift_add_same_image(idx, val))
      else                                                        # Base doesn't have the record
        @same = false
        row.merge!(drift_add_diff_image(idx, val))
      end
    else                                                          # Record is missing from this object
      if basval == "Found"                                        # Base has the record, no match
        @same = false
        row.merge!(drift_add_diff_image(idx, val))
      else
        img_src = "16/plus-black.png"              # Base doesn't have the record, match
        img_bkg = ""
        row.merge!(drift_add_image_col(idx, img_src, img_bkg, val))
      end
    end
    row
  end

  def drift_record_existmode(idx, val, basval)
    row = {}
    if val == "Found"                                             # This object has the record
      img_bkg = ""
      if basval == "Found"                                        # Base has the record
        img_src = "16/plus-black.png"
      else                                                        # Base doesn't have the record
        @same = false
        img_src = "16/plus-orange.png"
      end
      row.merge!(drift_add_image_col(idx, img_src, img_bkg, val))
    else                                                          # Record is missing from this object
      img_bkg = ""
      if basval == "Found"                                        # Base has the record, no match
        @same = false
        img_src = "16/minus-orange.png"
      else                                                        # Base doesn't have the record, match
        img_src = "16/minus-black.png"
      end
      row.merge!(drift_add_image_col(idx, img_src, img_bkg, val))
    end
    row
  end

  # Build a field row under a record row
  def drift_add_record_field(view, section, record, field)
    if @compressed  # Compressed
      row = drift_record_field_compressed(view, section, record, field)
    else  # Expanded
      row = drift_record_field_expanded(view, section, record, field)
    end
    row.merge!(:id           => "id_#{@rows.length}",
               :indent       => 2,
               :parent       => @record_parent_id,
               :record_field => true)
    @rows << row
  end

  def drift_record_field_compressed(view, section, record, field)
    basval = ""
    row = {:col0 => field[:header].to_s}

    view.ids.each_with_index do |id, idx|
      match_condition = view.results[view.ids[0]][section[:name]][record].nil? &&
                        view.results[id][section[:name]][record][field[:name]][:_match_]

      if !view.results[id][section[:name]][record].nil? && # Record exists
         !view.results[id][section[:name]][record][field[:name]].nil?      # Field exists

        val = view.results[id][section[:name]][record][field[:name]][:_value_].to_s
        row.merge!(drift_record_field_exists_compressed(idx, match_condition, val))
      else
        val = view.results[id][section[:name]].include?(record) ? "Found" : "Missing"
        basval = val if idx == 0       # On base object, # Hang on to base value
        row.merge!(drift_record_field_missing_compressed(idx, val, basval))
      end
    end
    row
  end

  def drift_record_field_expanded(view, section, record, field)
    row = {:col0 => field[:header].to_s}

    view.ids.each_with_index do |id, idx|
      if !view.results[id][section[:name]][record].nil? && !view.results[id][section[:name]][record][field[:name]].nil?

        match_condition = !view.results[view.ids[idx - 1]][section[:name]][record].nil? &&
                          !view.results[view.ids[idx - 1]][section[:name]][record][field[:name]].nil? &&
                          view.results[view.ids[idx - 1]][section[:name]][record][field[:name]][:_value_].to_s ==
                          view.results[id][section[:name]][record][field[:name]][:_value_].to_s

        val = view.results[id][section[:name]][record][field[:name]][:_value_].to_s
        row.merge!(drift_record_field_exists_expanded(idx, match_condition, val))
      else
        match_condition = !view.results[view.ids[0]][section[:name]][record].nil? &&
                          !view.results[view.ids[0]][section[:name]][record][field[:name]].nil?

        val = "(missing)"
        row.merge!(drift_record_field_missing_expanded(idx, match_condition, val))
      end
    end
    row
  end

  def drift_record_field_exists_compressed(idx, match_condition, val)
    row = {}
    if idx == 0   # On base object
      row = drift_add_same_image(idx, val)
    else          # Not on base object
      if !match_condition
        row.merge!(drift_add_same_image(idx, val))
      else
        row.merge!(drift_add_diff_image(idx, val))
      end
    end
    row
  end

  def drift_record_field_exists_expanded(idx, match_condition, val)
    row = {}
    if idx == 0
      img_bkg = "cell-stripe"
      row.merge!(drift_add_txt_col(idx, val, img_bkg))
    else
      if match_condition
        img_bkg = "cell-bkg-plain-no-shade"
        row.merge!(drift_add_txt_col(idx, val, img_bkg))
      else
        img_bkg = "cell-bkg-plain-mark-txt-no-shade"
        row.merge!(drift_add_txt_col(idx, val, img_bkg))
      end
    end
    row
  end

  def drift_record_field_missing_expanded(idx, match_condition, val)
    row = {}
    if idx == 0
      img_bkg = "cell-stripe"
      row.merge!(drift_add_txt_col(idx, val, img_bkg))
    else
      if match_condition
        img_bkg = "cell-bkg-plain-mark-txt-no-shade-no-bold"
        row.merge!(drift_add_txt_col(idx, val, img_bkg))
      else
        img_bkg = "cell-bkg-plain-mark-txt-black"
        row.merge!(drift_add_txt_col(idx, val, img_bkg))
      end
    end
    row
  end

  def drift_record_field_missing_compressed(idx, val, basval)
    row = {}
    if idx == 0       # On base object
      row.merge!(drift_add_same_image(idx, val))
    else              # Not on base object
      if basval == val # Matches base, then green
        row.merge!(drift_add_same_image(idx, val))
      else            # Doesn't match, then red
        row.merge!(drift_add_same_image(idx, val))
      end
    end
    row
  end

  # Build a field row under a section row
  def drift_add_section_field(view, section, field)
    @same = true
    if @compressed  # Compressed
      row = drift_add_section_field_compressed(view, section, field)
    else            # Expanded
      row = drift_add_section_field_expanded(view, section, field)
    end
    row.merge!(:id            => "id_#{@rows.length}",
               :indent        => 1,
               :parent        => @section_parent_id,
               :section_field => true)
    @rows << row
  end

  def drift_add_section_field_compressed(view, section, field)
    row = {:col0 => field[:header].to_s}
    view.ids.each_with_index do |id, idx|
      val = view.results[id][section[:name]][field[:name]][:_value_].to_s
      if !view.results[id][section[:name]][field[:name]].nil? && idx == 0     # On base object
        row.merge!(drift_add_same_image(idx, val))
      elsif !view.results[id][section[:name]].nil? && !view.results[id][section[:name]][field[:name]].nil?
        if view.results[id][section[:name]][field[:name]][:_match_]
          row.merge!(drift_add_same_image(idx, val))
        else
          @same = false
          row.merge!(drift_add_diff_image(idx, val))
        end
      else
        val = _("No Value Found")
        row.merge!(drift_add_diff_image(idx, val))
      end
    end
    row
  end

  def drift_add_section_field_expanded(view, section, field)
    row = {:col0 => field[:header]}
    view.ids.each_with_index do |id, idx|
      if !view.results[id][section[:name]][field[:name]].nil? && idx == 0       # On base object
        col = view.results[id][section[:name]][field[:name]][:_value_].to_s
        img_bkg = "cell-stripe"
        row.merge!(drift_add_txt_col(idx, col, img_bkg))
      elsif !view.results[id][section[:name]].nil? && !view.results[id][section[:name]][field[:name]].nil?
        if view.results[id][section[:name]][field[:name]][:_match_]
          col = view.results[id][section[:name]][field[:name]][:_value_].to_s
          img_bkg = "cell-bkg-plain-no-shade"
          row.merge!(drift_add_txt_col(idx, col, img_bkg))
        else
          @same = false
          col = view.results[id][section[:name]][field[:name]][:_value_].to_s
          img_bkg = "cell-bkg-plain-mark-txt-no-shade"
          row.merge!(drift_add_txt_col(idx, col, img_bkg))
        end
      end
    end
    row
  end

  def drift_add_same_image(idx, val)
    img_src = "100/compare-same.png"
    img_bkg = "cell-stripe"
    drift_add_image_col(idx, img_src, img_bkg, val)
  end

  def drift_add_diff_image(idx, val)
    img_src = "100/drift-delta.png"
    img_bkg = "cell-plain"
    drift_add_image_col(idx, img_src, img_bkg, val)
  end

  def drift_add_image_col(idx, img_src, img_bkg, val)
    html_text = "<div class='#{img_bkg}'>
                   <img src=\"#{ActionController::Base.helpers.image_path(img_src)}\" width=\"20\" height=\"20\"
                    border=\"0\" align=\"middle\" alt=\"#{val}\" title=\"#{val}\"/>
                 </div>"
    {"col#{idx + 1}".to_sym => html_text}
  end

  def drift_add_txt_col(idx, col, img_bkg)
    html_text = "<div class='#{img_bkg}'>#{col}</div>"
    {"col#{idx + 1}".to_sym => html_text}
  end

  # Render the view data to json for the grid view
  def compare_to_json(view)
    @rows = []
    @cols = []
    @compressed  = session[:miq_compressed]

    comp_add_header(view)
    comp_add_total(view)

    # Build the sections, records, and fields rows
    view.master_list.each_slice(3) do |section, records, fields| # section is a symbol, records and fields are arrays
      next unless view.include[section[:name]][:checked]
      comp_add_section(view, section, records, fields)    # Go build the section row if it's checked
      if !records.nil?      # If we have records, build record rows
        compare_build_record_rows(view, section, records, fields)
      else                  # Here if we have fields, with no records
        compare_build_field_rows(view, section, records, fields)
      end
    end
    comp_add_footer(view)
    @grid_rows_json = @rows.to_json.to_s.html_safe
    @grid_cols_json = @cols.to_json.to_s.html_safe

    @lastaction = "compare_miq"
  end

  def compare_build_record_rows(view, section, records, fields)
    records.each_with_index do |record, ridx|
      comp_add_record(view, section, record, ridx)
      unless compare_delete_row
        @rows.pop
        next
      end
      unless fields.nil?   # Build field rows under records
        fields.each_with_index do |field, _fidx|             # If we have fields, build field rows per record
          comp_add_record_field(view, section, record, field)
        end
      end
    end
  end

  def compare_build_field_rows(view, section, _records, fields)
    fields.each_with_index do |field, _fidx|                 # Build field rows per section
      comp_add_section_field(view, section, field)
      unless compare_delete_row
        @rows.pop
        next
      end
    end
  end

  def compare_delete_row
    @sb[:miq_temp_params].nil? ||
      @sb[:miq_temp_params] == "all" ||
      (@sb[:miq_temp_params] == "same" && @same) ||
      (@sb[:miq_temp_params] == "different" && !@same)
  end

  # Build the header row of the compare grid xml
  def comp_add_header(view)
    row = []
    rowtemp = {
      :id    => "col0",
      :name  => "",
      :field => "col0",
      :width => 220
    }
    row.push(rowtemp)
    view.records.each_with_index do |h, i|
      if @compressed
        html_text = comp_add_header_compressed(view, h, i)
      else
        html_text = comp_add_header_expanded(view, h, i)
      end
      rowtemp = {
        :id       => "col#{i + 1}",
        :field    => "col#{i + 1}",
        :width    => @compressed ? 40 : 190,
        :cssClass => "cell-effort-driven",
        :name     => html_text
      }
      row.push(rowtemp)
    end
    @cols = row
  end

  def comp_add_header_compressed(view, h, i)
    txt = h[:name].truncate(16)
    html_text = ""
    if %w(Vm VmOrTemplate).include?(@sb[:compare_db])
      img = ActionController::Base.helpers.image_path("100/vendor-#{h[:vendor].downcase}.png")
      html_text << "<a title=\"#{h[:name]}\" href=\"/#{controller_name}/show/#{h[:id]}\">
                      <img src=\"#{img}\" align=\"middle\" border=\"0\" width=\"20\" height=\"20\"/>
                    </a>"
    elsif @sb[:compare_db] == "Host"
      img = ActionController::Base.helpers.image_path("100/vendor-#{h[:vmm_vendor].downcase}.png")
      html_text << "<a href=\"/host/show/#{h[:id]}\">
                      <img src=\"#{img}\" align=\"middle\" border=\"0\" width=\"20\" height=\"20\" />
                    </a>"
    else
      img = ActionController::Base.helpers.image_path("100/#{@sb[:compare_db].underscore}.png")
      html_text <<
        "<a href=\"/ems_cluster/show/#{h[:id]}\">
          <img src=\"#{img}\" align=\"middle\" border=\"0\" width=\"20\" height=\"20\"/>
        </a>"
    end
    if i == 0
      html_text << "<a title='" + _("%{name} is the base") % {:name => h[:name]} + "'> #{txt.truncate(16)}</a>"
    else
      url = "/#{controller_name}/compare_choose_base/#{view.ids[i]}"
      html_text <<
        "<a title = '" + _("Make %{name} the base") % {:name => h[:name]} + "'
            onclick = \"miqJqueryRequest('#{url}',
                      {beforeSend: true, complete: true});\" href='#'>"
      html_text << "  #{txt.truncate(16)}"
      html_text << "</a>"
    end
    "<div class='rotated-text'>#{html_text}</div>"
  end

  def comp_add_header_expanded(view, h, i)
    render_to_string(
      :partial => 'shared/compare_header_expanded',
      :locals  => {
        :base  => i == 0,
        :vm_id => view.ids[i],
        :h     => h
      }
    )
  end

  def comp_add_footer(view)
    row = {
      :col0       => "",
      :id         => "id_#{@rows.length}",
      :remove_col => true
    }

    if view.ids.length > 2
      view.ids.each_with_index do |_id, idx|
        if idx != 0
          url = "/#{controller_name}/compare_remove/#{view.records[idx].id}"
          title = _("Remove this %{title} from the comparison") % {:title => session[:db_title].singularize}
          html_text = "<a onclick=\"miqJqueryRequest('#{url}', {beforeSend: true, complete: true}); return false;\"
                       title=\"#{title}\" href=\"#\">
                         <img src=\"#{ActionController::Base.helpers.image_path('toolbars/delete.png')}\"
                         width=\"24\" alt=\"#{title}\" title=\"#{title}\" align=\"middle\" border=\"0\" />
                       </a>"
          row.merge!("col#{idx + 1}".to_sym => html_text)
        end
      end
    end
    @rows << row
  end

  def compare_add_txt_col(idx, txt, tooltip = "", img_bkg = "cell-stripe", style = "")
    txt_tooltip = tooltip.empty? ? txt : tooltip
    txt_tooltip = "<abbr title='#{txt_tooltip}'>#{txt}</abbr>"
    if style.empty?
      html_text = "<div class='#{img_bkg} cell-text-wrap'>#{txt_tooltip}</div>"
    else
      html_text = "<div class='#{img_bkg} cell-text-wrap' style='#{style}'>#{txt_tooltip}</div>"
    end
    {"col#{idx + 1}".to_sym => html_text}
  end

  def compare_add_piechart_image(idx, val, image, img_bkg = "cell-plain")
    width = 55
    height = 25
    width = height = 24 if @compressed
    img_src = "100/piecharts/compare/#{image}.png"
    col = "<img src=\"#{ActionController::Base.helpers.image_path(img_src)}\" width=\"#{width}\" height=\"#{height}\"
           border=\"0\" align=\"middle\" alt=\"#{val}\" title=\"#{val}\">"
    html_text = "<div class='#{img_bkg}'>#{col}</div>"
    {"col#{idx + 1}".to_sym => html_text}
  end

  def compare_add_same_image(idx, val, img_bkg = "")
    img_src = "100/compare-same.png"
    drift_add_image_col(idx, img_src, img_bkg, val)
  end

  def compare_add_diff_image(idx, val)
    img_src = "100/compare-diff.png"
    img_bkg = ""
    drift_add_image_col(idx, img_src, img_bkg, val)
  end

  # Build the total row of the compare grid xml
  def comp_add_total(view)
    row = {
      :col0  => "<span class='cell-effort-driven cell-plain'>" + _("Total Matches") + "</span>",
      :id    => "id_#{@rows.length}",
      :total => true
    }
    view.ids.each_with_index do |_id, idx|
      if idx == 0
        row.merge!(compare_add_txt_col(idx, @compressed ? "%:" : _("% Matched:"), _("% Matched")))
      else
        key = @exists_mode ? :_match_exists_ : :_match_
        pct_match = view.results[view.ids[idx]][key]
        image = calculate_match_img(pct_match)
        row.merge!(compare_add_piechart_image(idx, "#{pct_match}% matched", image))
      end
    end
    @rows << row
  end

  # Build a section row for the compare grid xml
  def comp_add_section(view, section, records, fields)
    cell_text = section[:header]
    if records.nil? # Show records count if not nil
      cell_text += " (#{fields.length})"
    else                # Show fields count
      cell_text += " (#{records.length})"
    end
    row = {
      :col0       => cell_text,
      :id         => "id_#{@rows.length}",
      :indent     => 0,
      :parent     => nil,
      :section    => true,
      :exp_id     => section[:name].to_s,
      :_collapsed => collapsed_state(section[:name].to_s)
    }
    row.merge!(compare_section_data_cols(view, section, records))

    @section_parent_id = @rows.length
    @rows << row
  end

  def compare_section_data_cols(view, section, records)
    row = {}
    view.ids.each_with_index do |id, idx|
      if idx == 0
        row.merge!(compare_add_txt_col(idx, @compressed ? "%:" : _("% Matched:"), _("% Matched")))
      else
        key = @exists_mode && !records.nil? ? :_match_exists_ : :_match_
        pct_match = view.results[id][section[:name]][key]
        image = calculate_match_img(pct_match)
        row.merge!(compare_add_piechart_image(idx, "#{pct_match}% matched", image))
      end
    end
    row
  end

  def calculate_match_img(val)
    img = val == 100 ? 20 : ((val + 2) / 5.25).round    # val is the percentage value stored in _match_
    img
  end

  # Build a record row for the compare grid xml
  def comp_add_record(view, section, record, ridx)
    @same = true
    row = {
      :col0       => record,
      :id         => "id_#{@rows.length}",
      :indent     => 1,
      :parent     => @section_parent_id,
      :record     => true,
      :exp_id     => "#{section[:name]}_#{ridx}",
      :_collapsed => collapsed_state("#{section[:name]}_#{ridx}")
    }
    row.merge!(comp_record_data_cols(view, section, record))

    @record_parent_id = @rows.length
    @rows << row
  end

  def comp_record_data_cols(view, section, record)
    row = {}
    base_rec = view.results.fetch_path(view.ids[0], section[:name], record)
    basval = base_rec ? "Found" : "Missing"
    match = 0

    view.ids.each_with_index do |id, idx|                              # Go thru all of the objects
      rec = view.results.fetch_path(id, section[:name], record)
      rec_found = rec ? "Found" : "Missing"
      val = rec_found

      match = view.results[id][section[:name]][record][:_match_] if view.results[id][section[:name]][record]
      if @compressed  # Compressed, just show passed with hover value
        row.merge!(comp_record_data_compressed(idx, match, val, basval))
      else
        row.merge!(comp_record_data_expanded(idx, match, val, basval))
      end
    end
    row
  end

  def comp_record_data_compressed(idx, match, val, basval)
    row = {}
    if @exists_mode
      row.merge!(comp_record_data_compressed_existsmode(idx, match, val, basval))
    else
      row.merge!(comp_record_data_compressed_nonexistsmode(idx, match, val, basval))
    end
    row
  end

  def comp_record_data_compressed_existsmode(idx, _match, val, basval)
    row = {}
    if idx == 0                                                     # On the base?
      row.merge!(drift_add_image_col(idx, "100/blank.gif", "cell-stripe", val))
    else
      if val == basval  # Compare this object's value to the base
        row.merge!(compare_add_same_image(idx, val))
      else
        unset_same_flag
        row.merge!(compare_add_diff_image(idx, val))
      end
    end
    row
  end

  def comp_record_data_nonexistsmode(idx, match, val, basval)
    row = {}
    if idx == 0                                                     # On the base?
      row.merge!(compare_add_txt_col(idx, "%:", _("% Matched")))
    else
      if val == "Found"         # This object has the record
        if basval == "Found"    # Base has the record
          img_src = calculate_match_img(match)
          unset_same_flag(match)
          row.merge!(compare_add_piechart_image(idx, "#{match}% matched", img_src, ""))
        else
          unset_same_flag
          row.merge!(compare_add_piechart_image(idx, "0% matched", "0", ""))
        end
      else
        if basval == "Found"
          unset_same_flag
          row.merge!(compare_add_piechart_image(idx, "0% matched", "0", ""))
        else
          row.merge!(compare_add_piechart_image(idx, "100% matched", "20", ""))
        end
      end
    end
    row
  end

  def comp_record_data_compressed_nonexistsmode(idx, match, val, basval)
    comp_record_data_nonexistsmode(idx, match, val, basval)
  end

  def comp_record_data_expanded_nonexistsmode(idx, match, val, basval)
    comp_record_data_nonexistsmode(idx, match, val, basval)
  end

  def comp_record_data_expanded(idx, match, val, basval)
    row = {}
    if @exists_mode
      row.merge!(comp_record_data_expanded_existsmode(idx, match, val, basval))
    else
      row.merge!(comp_record_data_expanded_nonexistsmode(idx, match, val, basval))
    end
    row
  end

  def comp_record_data_expanded_existsmode(idx, _match, val, basval)
    row = {}
    if idx == 0                                                     # On the base?
      if val == "Found"                                           # Base has the record
        row.merge!(drift_add_image_col(idx, "16/plus-black.png", "cell-stripe", val))
      else                                                          # Base doesn't have the record
        unset_same_flag
        row.merge!(drift_add_image_col(idx, "16/minus-black.png", "cell-stripe", val))
      end
    else
      if val == "Found"                                             # This object has the record
        if basval == "Found"                                        # Base has the record
          row.merge!(drift_add_image_col(idx, "16/plus-green.png", "", val))
        else                                                        # Base doesn't have the record
          unset_same_flag
          row.merge!(drift_add_image_col(idx, "16/plus-red.png", "", val))
        end
      else                                                          # Record is missing from this object
        if basval == "Found"                                        # Base has the record, no match
          unset_same_flag
          row.merge!(drift_add_image_col(idx, "16/minus-red.png", "", val))
        else                                                        # Base doesn't have the record, match
          row.merge!(drift_add_image_col(idx, "16/minus-green.png", "", val))
        end
      end
    end
    row
  end

  def size_formatting(field_name, val)
    if ["used_space", "free_space", "size"].include?(field_name.to_s) && val != "(empty)"
      new_val = number_with_delimiter(val, :delimiter => ",", :separator => ".")
      return  new_val << " bytes"
    else
      return val.to_s
    end
  end

  # Build a field row under a record row
  def comp_add_record_field(view, section, record, field)
    row = {
      :col0         => field[:header],
      :id           => "id_#{@rows.length}",
      :indent       => 2,
      :parent       => @record_parent_id,
      :record_field => true
    }

    if @compressed  # Compressed
      row.merge!(comp_add_record_field_compressed(view, section, record, field))
    else  # Expanded
      row.merge!(comp_add_record_field_expanded(view, section, record, field))
    end
    @rows << row
  end

  def comp_add_record_field_compressed(view, section, record, field)
    row = {}
    base_rec = view.results.fetch_path(view.ids[0], section[:name], record)

    view.ids.each_with_index do |id, idx|
      rec = view.results.fetch_path(id, section[:name], record)
      rec_found = rec ? "Found" : "Missing"
      fld = rec.nil? ? nil : rec[field[:name]]

      if fld.nil?
        val = rec_found
        row.merge!(comp_add_record_field_missing_compressed(idx, val, base_rec))
      else
        val = fld[:_value_]
        row.merge!(comp_add_record_field_exists_compressed(idx, val, base_rec, field))
      end
    end
    row
  end

  def comp_add_record_field_missing_compressed(idx, val, base_rec)
    if @exists_mode
      passed_img = "passed"
      failed_img = "failed"
      img_path = "16"
    else
      passed_img = "compare-same"
      failed_img = "compare-diff"
      img_path = "100"
    end
    row = {}

    base_rec_found = base_rec ? "Found" : "Missing"

    if idx == 0       # On base object
      row.merge!(drift_add_same_image(idx, val))
    else              # Not on base object
      row.merge!(drift_add_image_col(idx,
                                     "#{img_path}/#{base_rec_found == val ? passed_img : failed_img}.png",
                                     "",
                                     val))
    end
    row
  end

  def comp_add_record_field_exists_compressed(idx, val, base_rec, field)
    if @exists_mode
      passed_img = "passed"
      failed_img = "failed"
      img_path = "16"
    else
      passed_img = "compare-same"
      failed_img = "compare-diff"
      img_path = "100"
    end
    row = {}

    base_fld = base_rec.nil? ? nil : base_rec[field[:name]]
    base_val = base_fld.nil? ? nil : base_fld[:_value_]

    if idx == 0   # On base object
      row.merge!(drift_add_same_image(idx, val))
    else          # Not on base object
      row.merge!(drift_add_image_col(idx, "#{img_path}/#{base_val == val ? passed_img : failed_img}.png", "", val))
    end
    row
  end

  def comp_add_record_field_expanded(view, section, record, field)
    row = {}
    base_rec = view.results.fetch_path(view.ids[0], section[:name], record)

    view.ids.each_with_index do |id, idx|
      fld = view.results.fetch_path(id, section[:name], record, field[:name])
      val = fld.nil? ? nil : fld[:_value_]

      if fld.nil?
        row.merge!(comp_add_record_field_missing_expanded(idx, base_rec, field))
      else
        row.merge!(comp_add_record_field_exists_expanded(idx, val, base_rec, field))
      end
    end
    row
  end

  def comp_add_record_field_exists_expanded(idx, val, base_rec, field)
    if @exists_mode
      passed_text_color = failed_text_color = "black"
    else
      passed_text_color = "#403990"
      failed_text_color = "#21a0ec"
    end
    row = {}

    base_fld = base_rec.nil? ? nil : base_rec[field[:name]]
    base_val = base_fld.nil? ? nil : base_fld[:_value_]

    if idx == 0
      row.merge!(compare_add_txt_col(idx, val))
    else
      style = "color:#{base_val == val ? passed_text_color : failed_text_color};"
      row.merge!(compare_add_txt_col(idx, size_formatting(field[:name], val), "", "", style))
    end
    row
  end

  def comp_add_record_field_missing_expanded(idx, base_rec, field)
    if @exists_mode
      passed_text_color = failed_text_color = "black"
    else
      passed_text_color = "#403990"
      failed_text_color = "#21a0ec"
    end
    row = {}
    base_fld = base_rec.nil? ? nil : base_rec[field[:name]]

    if idx == 0
      row.merge!(compare_add_txt_col(idx, _("(missing)")))
    else
      style = "color:#{base_fld.nil? ? passed_text_color : failed_text_color};"
      row.merge!(compare_add_txt_col(idx, _("(missing)"), "", "", style))
    end
    row
  end

  # Build a field row under a section row
  def comp_add_section_field(view, section, field)
    @same = true

    row = {
      :col0          => field[:header],
      :id            => "id_#{@rows.length}",
      :indent        => 1,
      :parent        => @section_parent_id,
      :section_field => true
    }

    if @compressed  # Compressed
      row.merge!(comp_add_section_field_compressed(view, section, field))
    else            # Expanded
      row.merge!(comp_add_section_field_expanded(view, section, field))
    end

    @rows << row
  end

  def comp_add_section_field_compressed(view, section, field)
    row = {}
    base_val = view.results.fetch_path(view.ids[0], section[:name], field[:name], :_value_)
    view.ids.each_with_index do |id, idx|
      fld = view.results.fetch_path(id, section[:name], field[:name])
      val = fld[:_value_] unless fld.nil?

      if fld.nil?
        row.merge!(compare_add_diff_image(idx, _("No Value Found")))
      elsif idx == 0      # On base object
        row.merge!(compare_add_same_image(idx, val, "cell-stripe"))
      else
        if base_val == val
          img_bkg = "cell-stripe"
          img = "compare-same"
        else
          img_bkg = ""
          img = "compare-diff"
          unset_same_flag
        end
        row.merge!(drift_add_image_col(idx, "100/#{img}.png", img_bkg, val))
      end
    end
    row
  end

  def comp_add_section_field_expanded(view, section, field)
    row = {}
    base_val = view.results.fetch_path(view.ids[0], section[:name], field[:name], :_value_)
    view.ids.each_with_index do |id, idx|
      fld = view.results.fetch_path(id, section[:name], field[:name])
      next if fld.nil?
      val = fld[:_value_]

      if idx == 0       # On base object
        row.merge!(compare_add_txt_col(idx, val))
      else
        if base_val == val
          style = "color:#403990;font-weight:bold;"
          img_bkg = "cell-stripe"
        else
          style = "color:#21a0ec;font-weight:bold;"
          img_bkg = ""
          unset_same_flag
        end
        row.merge!(compare_add_txt_col(idx, val, "", img_bkg, style))
      end
    end
    row
  end

  def unset_same_flag(match = 0)
    @same = false if match != 100
  end

  # Render the view data to xml for the grid view
  def drift_to_json(view)
    @rows = []
    @cols = []
    @layout = view.report.db == "VmOrTemplate" ? @sb[:compare_db].underscore : view.report.db.underscore
    @compressed = session[:miq_compressed]
    @exists_mode = session[:miq_exists_mode]

    drift_add_header(view)
    drift_add_total(view)

    # Build the sections, records, and fields rows
    view.master_list.each_slice(3) do |section, records, fields| # section is a symbol, records and fields are arrays
      if view.include[section[:name]][:checked]
        drift_add_section(view, section, records, fields)   # Go build the section row if it's checked
        if !records.nil?      # If we have records, build record rows
          drift_build_record_rows(view, section, records, fields)
        else                  # Here if we have fields, with no records
          drift_build_field_rows(view, section, fields)
        end
      end
      @grid_rows_json = @rows.to_json.to_s.html_safe
      @grid_cols_json = @cols.to_json.to_s.html_safe
    end
    @lastaction = "drift"
  end

  def drift_build_record_rows(view, section, records, fields)
    records.each_with_index do |record, ridx|
      drift_add_record(view, section, record, ridx)
      unless drift_delete_row
        @rows.pop
        next
      end
      if !fields.nil? && !@exists_mode  # Build field rows under records
        fields.each_with_index do |field, _fidx|             # If we have fields, build field rows per record
          drift_add_record_field(view, section, record, field)
        end
      end
    end
  end

  def drift_build_field_rows(view, section, fields)
    fields.each_with_index do |field, _fidx|                 # Build field rows per section
      drift_add_section_field(view, section, field)
      unless drift_delete_row
        @rows.pop
        next
      end
    end
  end

  def drift_delete_row
    @sb[:miq_drift_params].nil? ||
      @sb[:miq_drift_params] == "all" ||
      (@sb[:miq_drift_params] == "same" && @same) ||
      (@sb[:miq_drift_params] == "different" && !@same)
  end

  def collapsed_state(id)
    s = session[:compare_state] || []
    !s.include?(id)
  end
end
