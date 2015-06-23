class AdvancedSearchesController < ApplicationController
  # Clear the applied search
  def clear
    respond_to do |format|
      format.js do
        @explorer = true
        if x_tree[:type] == :filter &&
            !["Vm", "MiqTemplate"].include?(TreeBuilder.get_model_for_prefix(@nodetype))
          search_id = 0
          if x_active_tree == :cs_filter_tree
            adv_search_build("ConfiguredSystem")
          else
            adv_search_build(vm_model_from_active_tree(x_active_tree))
          end
          session[:edit] = @edit              # Set because next method will restore @edit from session
          listnav_search_selected(search_id)  # Clear or set the adv search filter
          self.x_node = "root"
        end
        replace_right_cell
      end
      format.html do
        @edit = session[:edit]
        @view = session[:view]
        @edit[:adv_search_applied] = nil
        @edit[:expression][:exp_last_loaded] = nil
        session[:adv_search] ||= Hash.new                   # Create/reuse the adv search hash
        session[:adv_search][@edit[@expkey][:exp_model]] = copy_hash(@edit) # Save by model name in settings
        if @settings[:default_search] && @settings[:default_search][@view.db.to_s.to_sym] && @settings[:default_search][@view.db.to_s.to_sym].to_i != 0
          s = MiqSearch.find(@settings[:default_search][@view.db.to_s.to_sym])
          @edit[@expkey][:selected] = {:id=>s.id, :name=>s.name, :description=>s.description, :typ=>s.search_type}        # Save the last search loaded
          @edit[:selected] = false
        else
          @edit[@expkey][:selected] = {:id=>0}
          @edit[:selected] = true     # Set a flag, this is checked whether to load initial default or clear was clicked
        end
        redirect_to(:action=>"show_list")
      end
      format.any {render :nothing=>true, :status=>404}  # Anything else, just send 404
    end
  end

  def toggle
    @edit = session[:edit]

    # Rebuild the pulldowns if opening the search box
    adv_search_build_lists unless @edit[:adv_search_open]
    exp_get_prefill_types unless @edit[:adv_search_open]

    render :update do |page|
      if @edit[:adv_search_open] == true
        @edit[:adv_search_open] = false
        page << "$('#adv_search_img').prop('src', '/images/toolbars/squashed-true.png')"
        page << javascript_hide("advsearchModal")
        page << javascript_hide("blocker_div")
      else
        @edit[:adv_search_open] = true
        page << "$('#clear_search').#{clear_search_show_or_hide}();"
        page.replace("adv_search_body", :partial => "layouts/adv_search_body", :locals => {
          :target_controller => params[:target_controller]
        })
        page.replace("adv_search_footer", :partial => "layouts/adv_search_footer", :locals => {
          :target_controller => params[:target_controller]
        })
        page << "$('#adv_search_img').prop('src', '/images/toolbars/squashed-false.png')"
        if [:date, :datetime].include?(@edit.fetch_path(@expkey, :val1, :type)) ||
            [:date, :datetime].include?(@edit.fetch_path(@expkey, :val2, :type))
          page << "miqBuildCalendar();"
        end

        page << "miq_val1_type = '#{@edit[@expkey][:val1][:type]}';" if @edit.fetch_path(@expkey,:val1,:type)
        page << "miq_val1_title = '#{@edit[@expkey][:val1][:title]}';" if @edit.fetch_path(@expkey,:val1,:type)
        page << "miq_val2_type = '#{@edit[@expkey][:val2][:type]}';" if @edit.fetch_path(@expkey,:val2,:type)
        page << "miq_val2_title = '#{@edit[@expkey][:val2][:title]}';" if @edit.fetch_path(@expkey,:val2,:type)
      end
      page << set_spinner_off
      # Rememeber this settting in the model settings
      if session.fetch_path(:adv_search, @edit[@expkey][:exp_model])
        session[:adv_search][@edit[@expkey][:exp_model]][:adv_search_open] = @edit[:adv_search_open]
      end
    end
  end

  def button
    @edit = session[:edit]
    @view = session[:view]
    @edit[:custom_search] = false             # setting default to false
    case params[:button]
    when "saveit"
      if @edit[:new_search_name] == nil || @edit[:new_search_name] == ""
        add_flash(_("%s is required") % "Search Name", :error)
        params[:button] = "save"                                    # Redraw the save screen
      else
#       @edit[:new][@expkey] = copy_hash(@edit[@expkey][:expression]) # Copy the current expression to new
        if @edit[@expkey][:selected] == nil ||                        # If no search was loaded
            @edit[:new_search_name] != @edit[@expkey][:selected][:description] || # or user changed the name of a loaded search
            @edit[@expkey][:selected][:typ] == "default"                          # or loaded search is a default search, save it as my search
          s = MiqSearch.new                                         # Adding a new search
          s.db = @edit[@expkey][:exp_model]                         # Set the model
          s.description = @edit[:new_search_name]
          if @edit[:search_type]        # adding global search
            s.name = "global_#{@edit[:new_search_name]}"            # Set the unique name within searches
            s.search_key = nil                                      # Set userid that saved search
            s.search_type = "global"
          else                  #adding user search
            s.name = "user_#{session[:userid]}_#{@edit[:new_search_name]}"          # Set the unique name within searches
            s.search_key = session[:userid]                                         # Set userid that saved search
            s.search_type = "user"
          end
        else          # if search was loaded exists or saving it with same name
          s = MiqSearch.find(@edit[@expkey][:selected][:id])            # Fetch the last search loaded
          if @edit[:search_type]
            if s.name != "global_#{@edit[:new_search_name]}"              # if search selected was not global, create new search
              s = MiqSearch.new
              s.db = @edit[@expkey][:exp_model]                         # Set the model
              s.description = @edit[:new_search_name]
            end
            s.name = "global_#{@edit[:new_search_name]}"                # Set the unique name within searches
            s.search_key = nil                                          # Set userid that saved search
            s.search_type = "global"
          else                  #adding user search
            if s.name != "user_#{session[:userid]}_#{@edit[:new_search_name]}"              # if search selected was not my search, create new search
              s = MiqSearch.new
              s.db = @edit[@expkey][:exp_model]                         # Set the model
              s.description = @edit[:new_search_name]
            end
            s.name = "user_#{session[:userid]}_#{@edit[:new_search_name]}"          # Set the unique name within searches
            s.search_key = session[:userid]                                         # Set userid that saved search
            s.search_type = "user"
          end
        end
        s.filter = MiqExpression.new(@edit[:new][@expkey])      # Set the new expression
        if s.save
#         AuditEvent.success(build_created_audit(s, s_old))
          add_flash(_("%{model} \"%{name}\" was saved") % {:model=>"#{ui_lookup(:model=>@edit[@expkey][:exp_model])} search", :name=>@edit[:new_search_name]})
          # converting expressions into Array here, so Global views can be oushed into it and be shown on the top with Global Prefix in load pull down
          global_expressions = MiqSearch.get_expressions(:db=>@edit[@expkey][:exp_model],
                                                                              :search_type=>"global")
          @edit[@expkey][:exp_search_expressions] = MiqSearch.get_expressions(:db=>@edit[@expkey][:exp_model],
                                                                              :search_type=>"user",
                                                                              :search_key=>session[:userid])      #Rebuild the list of searches
          @edit[@expkey][:exp_search_expressions] = Array(@edit[@expkey][:exp_search_expressions]).sort
          global_expressions = Array(global_expressions).sort if !global_expressions.blank?
          if !global_expressions.blank?
            global_expressions.each_with_index do |ge,i|
              global_expressions[i][0] = "Global - #{ge[0]}"
              @edit[@expkey][:exp_search_expressions] = @edit[@expkey][:exp_search_expressions].unshift(global_expressions[i])
            end
          end
          @edit[@expkey][:exp_last_loaded] = {:id=>s.id, :name=>s.name, :description=>s.description, :typ=>s.search_type}     # Save the last search loaded (saved)
          #@edit[@expkey][:selected] = @edit[@expkey][:exp_last_loaded] = {:id=>s.id, :name=>s.name, :description=>s.description, :typ=>s.search_type}      # Save the last search loaded (saved)
          @edit[:new_search_name] = @edit[:adv_search_name] = @edit[@expkey][:exp_last_loaded][:description]
          @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
          @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Build the expression table
          exp_array(:init, @edit[@expkey][:expression])
          @edit[@expkey][:exp_token] = nil                                        # Clear the current selected token
        else
          s.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          params[:button] = "save"                                  # Redraw the save screen
        end
      end

    when "loadit"
      if @edit[@expkey][:exp_chosen_search]
        @edit[:selected] = true
        s = MiqSearch.find(@edit[@expkey][:exp_chosen_search].to_s)
        @edit[:new][@expkey] = s.filter.exp
        @edit[@expkey][:selected] = @edit[@expkey][:exp_last_loaded] = {:id=>s.id, :name=>s.name, :description=>s.description, :typ=>s.search_type}       # Save the last search loaded
      elsif @edit[@expkey][:exp_chosen_report]
        r = MiqReport.find(@edit[@expkey][:exp_chosen_report].to_s)
        @edit[:new][@expkey] = r.conditions.exp
        @edit[@expkey][:exp_last_loaded] = nil                                # Clear the last search loaded
        @edit[:adv_search_report] = r.name                          # Save the report name
      end
      @edit[:new_search_name] = @edit[:adv_search_name] = @edit[@expkey][:exp_last_loaded] == nil ? nil : @edit[@expkey][:exp_last_loaded][:description]
      @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Build the expression table
      exp_array(:init, @edit[@expkey][:expression])
      @edit[@expkey][:exp_token] = nil                                        # Clear the current selected token
      add_flash(_("%{model} \"%{name}\" was successfully loaded") % {:model=>"#{ui_lookup(:model=>@edit[@expkey][:exp_model])} search", :name=>@edit[:new_search_name]})

    when "delete"
      s = MiqSearch.find(@edit[@expkey][:selected][:id])              # Fetch the latest record
      id = s.id
      sname = s.description
      begin
        s.destroy                                                   # Delete the record
      rescue StandardError => bang
        add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model => ui_lookup(:model => "MiqSearch"), :name  => sname, :task  => "delete"} << bang.message,
                  :error)
      else
        if @settings[:default_search] && @settings[:default_search][@edit[@expkey][:exp_model].to_s.to_sym] # See if a default search exists
          def_search = @settings[:default_search][@edit[@expkey][:exp_model].to_s.to_sym]
          if id.to_i == def_search.to_i
            db_user = current_user
            db_user.settings[:default_search].delete(@edit[@expkey][:exp_model].to_s.to_sym)
            db_user.save
            @edit[:adv_search_applied] = nil          # clearing up applied search results
          end
        end
        add_flash(_("%{model} \"%{name}\": Delete successful") % {:model=>"#{ui_lookup(:model=>@edit[@expkey][:exp_model])} search", :name=>sname})
        audit = {:event=>"miq_search_record_delete",
                :message=>"[#{sname}] Record deleted",
                :target_id=>id,
                :target_class=>"MiqSearch",
                :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      # converting expressions into Array here, so Global views can be oushed into it and be shown on the top with Global Prefix in load pull down
      global_expressions = MiqSearch.get_expressions(:db=>@edit[@expkey][:exp_model],
                                                                          :search_type=>"global")
      @edit[@expkey][:exp_search_expressions] = MiqSearch.get_expressions(:db=>@edit[@expkey][:exp_model],
                                                                          :search_type=>"user",
                                                                          :search_key=>session[:userid])      #Rebuild the list of searches
      @edit[@expkey][:exp_search_expressions] = Array(@edit[@expkey][:exp_search_expressions]).sort
      global_expressions = Array(global_expressions).sort if !global_expressions.blank?
      if !global_expressions.blank?
        global_expressions.each_with_index do |ge,i|
          global_expressions[i][0] = "Global - #{ge[0]}"
          @edit[@expkey][:exp_search_expressions] = @edit[@expkey][:exp_search_expressions].unshift(global_expressions[i])
        end
      end
    when "reset"
      add_flash(_("The current search details have been reset"), :warning)

    when "apply"
      @edit[@expkey][:selected] = @edit[@expkey][:exp_last_loaded] # Save the last search loaded (saved)
      @edit[:adv_search_applied] ||= Hash.new
      @edit[:adv_search_applied][:exp] = Hash.new
      adv_search_set_text # Set search text filter suffix
      @edit[:selected] = true
      @edit[:adv_search_applied][:exp] = @edit[:new][@expkey]   # Save the expression to be applied
      @edit[@expkey].delete(:exp_token)                         # Remove any existing atom being edited
      @edit[:adv_search_open] = false                           # Close the adv search box
      if MiqExpression.quick_search?(@edit[:adv_search_applied][:exp])
        quick_search_show
        return
      else
        @edit[:adv_search_applied].delete(:qs_exp)            # Remove any active quick search
        session[:adv_search] ||= Hash.new                     # Create/reuse the adv search hash
        session[:adv_search][@edit[@expkey][:exp_model]] = copy_hash(@edit) # Save by model name in settings
      end
      if @edit[:in_explorer]
        self.x_node = "root"                                      # Position on root node
        replace_right_cell
      else
        render :update do |page|
          page.redirect_to :controller => params[:target_controller], :action => 'show_list'                 # redirect to build the list screen
        end
      end
      return

    when "cancel"
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Rebuild the existing expression table
      exp_get_prefill_types                                     # Get the prefill field type
    end

    # Reset fields if delete or reset ran
    if ["delete","reset"].include?(params[:button])
      @edit[@expkey][:expression] = {"???"=>"???"}              # Set as new exp element
      @edit[:new][@expkey] = @edit[@expkey][:expression]        # Copy to new exp
      exp_array(:init, @edit[@expkey][:expression])             # Initialize the exp array
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Rebuild the expression table
      @edit[@expkey][:exp_last_loaded] = nil                    # Clear the last search loaded
      @edit[:adv_search_name] = nil                             # Clear search name
      @edit[:adv_search_report] = nil                           # Clear the report name
    elsif params[:button] == "save"
        @edit[:search_type] = nil
    end

    if ["delete","saveit"].include?(params[:button])
      if @edit[:in_explorer]
        if "cs_filter_tree" == x_active_tree.to_s
          build_foreman_tree(:filter, x_active_tree)
        else
          build_vm_tree(:filter, x_active_tree) # Rebuild active VM filter tree
        end
      else
        build_listnav_search_list(@edit[@expkey][:exp_model])
      end
    end

    render :update do |page|
      if ["load","save"].include?(params[:button])
        page.replace("adv_search_body", :partial => "layouts/adv_search_body", :locals => {
          :mode => params[:button],
          :target_controller => params[:target_controller]
        })
        page.replace("adv_search_footer", :partial => "layouts/adv_search_footer",
                                          :locals  => {:mode => params[:button], :target_controller => params[:target_controller]})
      else
        @edit[@expkey][:exp_chosen_report] = nil
        @edit[@expkey][:exp_chosen_search] = nil
        page.replace("adv_search_body", :partial => "layouts/adv_search_body", :locals => {
          :target_controller => params[:target_controller]
        })
        page.replace("adv_search_footer", :partial => "layouts/adv_search_footer", :locals => {
          :target_controller => params[:target_controller]
        })
      end

      if ["delete","saveit"].include?(params[:button])
        if @edit[:in_explorer]
          tree = x_active_tree.to_s
          if "cs_filter_tree" == tree
            page.replace_html("#{tree}_div", :partial => "provider_foreman/#{tree}")
          else
            page.replace_html("#{tree}_div", :partial => "vm_common/#{tree}")
          end
        else
          page.replace(:listnav_div, :partial=>"layouts/listnav")
        end
      end
    end
  end

  # One of the load choices was selected on the advanced search load panel
  def load_choice
    @edit = session[:edit]
    if params[:chosen_search]
      @edit[@expkey][:exp_chosen_report] = nil
      if params[:chosen_search] == "0"
        @edit[@expkey][:exp_chosen_search] = nil
      else
        @edit[@expkey][:exp_chosen_search] = params[:chosen_search].to_i
        @exp_to_load = exp_build_table(MiqSearch.find(params[:chosen_search]).filter.exp)
      end
    else
      @edit[@expkey][:exp_chosen_search] = nil
      if params[:chosen_report] == "0"
        @edit[@expkey][:exp_chosen_report] = nil
      else
        @edit[@expkey][:exp_chosen_report] = params[:chosen_report].to_i
        @exp_to_load = exp_build_table(MiqReport.find(params[:chosen_report]).conditions.exp)
      end
    end
    render :update do |page|
    page.replace("adv_search_body", :partial => "layouts/adv_search_body", :locals => {
      :mode => 'load',
      :target_controller => params[:target_controller]
    })
    page.replace("adv_search_footer", :partial => "layouts/adv_search_footer", :locals => {
      :mode => 'load',
      :target_controller => params[:target_controller]
    })
    end
  end

  # Character typed into search name field
  def name_typed
    @edit = session[:edit]
    @edit[:new_search_name] = params[:search_name] if params[:search_name]
    @edit[:search_type] = params[:search_type].to_s == "1" ? "global" : nil if params[:search_type]
    render :update do |page|
    end
  end

  # Handle buttons pressed in the expression editor
  def exp_button
    @edit = session[:edit]
    div_num = @edit[:flash_div_num] ? @edit[:flash_div_num] : ""
    case params[:pressed]
    when "undo", "redo"
      @edit[@expkey][:expression] = exp_array(params[:pressed].to_sym)
      @edit[:new][@expkey] = copy_hash(@edit[@expkey][:expression])
    when "not"
      exp_add_not(@edit[@expkey][:expression], @edit[@expkey][:exp_token])
    when "and", "or"
      exp_add_joiner(@edit[@expkey][:expression], @edit[@expkey][:exp_token], params[:pressed])
    when "commit"
      exp_commit(@edit[@expkey][:exp_token])
    when "remove"
      remove_top = exp_remove(@edit[@expkey][:expression], @edit[@expkey][:exp_token])
      if remove_top == true
        exp = @edit[@expkey][:expression]
        if exp["not"]                                       # If the top expression is a NOT
          exp["not"].each_key do |key|                      # Find the next lower key
            next if key == :token                           # Skip the :token key
            exp[key] = exp["not"][key]                      # Copy the key value up to the top
            exp.delete("not")                               # Delete the NOT key
          end
        else
          exp.each_key {|key| exp.delete(key)}              # Remove all existing keys
          exp["???"] = "???"                                # Set new exp key
          @edit[:edit_exp] = copy_hash(exp)
          exp_set_fields(@edit[:edit_exp])
        end
      else
        @edit[:edit_exp] = nil
      end
    when "discard"
      # Copy back the latest expression or empty expression, if nil
      @edit[@expkey].delete(:val1)
      @edit[@expkey].delete(:val2)
      @edit[@expkey][:expression] = @edit[:new][@expkey].nil? ? {"???"=>"???"} : copy_hash(@edit[:new][@expkey])
      @edit.delete(:edit_exp)
    else
      add_flash(_("Button not yet implemented"), :error)
    end

    if flash_errors?
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_div#{div_num}", :partial=>"layouts/flash_msg", :locals=>{:div_num=>div_num})
      end
    else
      if ["commit", "not", "remove"].include?(params[:pressed])
        copy = copy_hash(@edit[@expkey][:expression])
        copy.deep_delete :token
        @edit[:new][@expkey] = copy
        exp_array(:push, @edit[:new][@expkey])
      end
      unless ["and", "or"].include?(params[:pressed]) # Unless adding an AND or OR token
        @edit[@expkey][:exp_token] = nil                        #   clear the current selected token
      end
      changed = (@edit[:new] != @edit[:current])
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_div#{div_num}", :partial=>"layouts/flash_msg", :locals=>{:div_num=>div_num})
#       page.replace("form_expression_div", :partial=>"form_expression")
        if @edit[:adv_search_open] != nil
          page.replace("adv_search_body", :partial => "layouts/adv_search_body", :locals => {
            :target_controller => params[:target_controller]
          })
          page.replace("adv_search_footer", :partial => "layouts/adv_search_footer", :locals => {
            :target_controller => params[:target_controller]
          })
        else
          page.replace("exp_editor_div", :partial=>"layouts/exp_editor")
        end
        if ["not","discard","commit","remove"].include?(params[:pressed])
          page << javascript_hide("exp_buttons_on")
          page << javascript_hide("exp_buttons_not")
          page << javascript_show("exp_buttons_off")
        end
        if changed != session[:changed]
          session[:changed] = changed
          page << javascript_for_miq_button_visibility(changed)
        end
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  # A token was pressed on the exp editor
  def exp_token_pressed
    @edit = session[:edit]
    div_num = @edit[:flash_div_num] ? @edit[:flash_div_num] : ""
    token = params[:token].to_i
    if token == @edit[@expkey][:exp_token] ||         # User selected same token as already selected
       (@edit[@expkey][:exp_token] && @edit[:edit_exp].has_key?("???")) # or new token in process
      render :update do |page|                        # Leave the page as is
        page.replace("flash_msg_div#{div_num}", :partial=>"layouts/flash_msg", :locals=>{:div_num=>div_num})
      end
    else
      exp = exp_find_by_token(@edit[@expkey][:expression], token)
      @edit[:edit_exp] = copy_hash(exp)
      begin
        exp_set_fields(@edit[:edit_exp])
      rescue StandardError=>bang
        @exp_atom_errors = [_("There is an error in the selected expression element, perhaps it was imported or edited manually."),
                            _("This element should be removed and recreated or you can report the error to your CFME administrator."),
                            _("Error details: %s") % bang]
      end
      @edit[@expkey][:exp_token] = token
      render :update do |page|
        page.replace("flash_msg_div#{div_num}", :partial=>"layouts/flash_msg", :locals=>{:div_num=>div_num})
        page.replace("exp_editor_div", :partial=>"layouts/exp_editor")
        page << "$('#exp_#{token}').css({'background-color': 'yellow'})"
        page << javascript_hide("exp_buttons_off")
        if exp.has_key?("not") or @parent_is_not
          page << javascript_hide("exp_buttons_on")
          page << javascript_show("exp_buttons_not")
        else
          page << javascript_hide("exp_buttons_not")
          page << javascript_show("exp_buttons_on")
        end

        if [:date, :datetime].include?(@edit.fetch_path(@expkey, :val1, :type)) ||
            [:date, :datetime].include?(@edit.fetch_path(@expkey, :val2, :type))
          page << "miqBuildCalendar();"
        end

        if @edit[@expkey][:exp_key] && @edit[@expkey][:exp_field]
          page << "miq_val1_type = '#{@edit[@expkey][:val1][:type]}';" if @edit[@expkey][:val1][:type]
          page << "miq_val1_title = '#{@edit[@expkey][:val1][:title]}';" if @edit[@expkey][:val1][:type]
          page << "miq_val2_type = '#{@edit[@expkey][:val2][:type]}';" if @edit[@expkey][:val2][:type]
          page << "miq_val2_title = '#{@edit[@expkey][:val2][:title]}';" if @edit[@expkey][:val2][:type]
        end
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  # Handle items changed in the expression editor
  def exp_changed
    @edit = session[:edit]
    div_num = @edit[:flash_div_num] ? @edit[:flash_div_num] : ""
    if params[:chosen_typ] && params[:chosen_typ] != @edit[@expkey][:exp_typ] # Did the type field change?
      @edit[@expkey][:exp_typ] = params[:chosen_typ]

      @edit[@expkey][:exp_key] = nil                  # Clear operators and values
      @edit[@expkey][:alias] = nil
      @edit[@expkey][:exp_skey] = nil
      @edit[@expkey][:exp_ckey] = nil
      @edit[@expkey][:exp_value] = nil
      @edit[@expkey][:exp_cvalue] = nil
      @edit[@expkey][:exp_regkey] = nil
      @edit[@expkey][:exp_regval] = nil
      @edit[:suffix] = @edit[:suffix2] = nil

      case @edit[@expkey][:exp_typ]                   # Change the exp fields based on the new type
      when "<Choose>"
        @edit[@expkey][:exp_typ] = nil
      when "field"
        @edit[@expkey][:exp_field] = nil
      when "count"
        @edit[@expkey][:exp_count] = nil
        @edit[@expkey][:exp_key] = MiqExpression.get_col_operators(:count).first
        exp_get_prefill_types                         # Get the field type
      when "tag"
        @edit[@expkey][:exp_tag] = nil
        @edit[@expkey][:exp_key] = "CONTAINS"
      when "regkey"
        @edit[@expkey][:exp_key] = MiqExpression.get_col_operators(:regkey).first
        exp_get_prefill_types                         # Get the field type
      when "find"
        @edit[@expkey][:exp_field] = nil
        @edit[@expkey][:exp_key] = "FIND"
        @edit[@expkey][:exp_check] = "checkall"
        @edit[@expkey][:exp_cfield] = nil
      end
    else
      case @edit[@expkey][:exp_typ]                   # Check the type of expression we are dealing with
      when "field"
        if params[:chosen_field] && params[:chosen_field] != @edit[@expkey][:exp_field] # Did the field change?
          @edit[@expkey][:exp_field] = params[:chosen_field]        # Save the field
          @edit[@expkey][:exp_value] = nil                          # Clear the value
          @edit[:suffix] = nil                                      # Clear the suffix
          unless params[:chosen_field] == "<Choose>"
            if @edit[@expkey][:exp_model] != "_display_filter_" && MiqExpression.is_plural?(@edit[@expkey][:exp_field])
              @edit[@expkey][:exp_key] = "CONTAINS"                 # CONTAINS only valid for plural tables
            else
              @edit[@expkey][:exp_key] = nil unless MiqExpression.get_col_operators(@edit[@expkey][:exp_field]).include?(@edit[@expkey][:exp_key])  # Remove if not in list
              @edit[@expkey][:exp_key] ||= MiqExpression.get_col_operators(@edit[@expkey][:exp_field]).first  # Default to first operator
            end
            exp_get_prefill_types                                   # Get the field type
            process_datetime_expression_field(:val1, :exp_key, :exp_value)
          else
            @edit[@expkey][:exp_field] = nil
            @edit[@expkey][:exp_key] = nil
          end
          @edit[@expkey][:alias] = nil
        end

        if params[:chosen_key] && params[:chosen_key] != @edit[@expkey][:exp_key] # Did the key change?
          process_changed_expression(params, :chosen_key, :exp_key, :exp_value, :val1)
        end

        if ui = params[:user_input]
          @edit[@expkey][:exp_value] = ui == "1" ? :user_input : ""
        end
      when "count"
        if params[:chosen_count] && params[:chosen_count] != @edit[@expkey][:exp_count] # Did the count field change?
          unless params[:chosen_count] == "<Choose>"
            @edit[@expkey][:exp_count] = params[:chosen_count]                          # Save the field
            @edit[@expkey][:exp_key] = nil unless MiqExpression.get_col_operators(:count).include?(@edit[@expkey][:exp_key])  # Remove if not in list
            @edit[@expkey][:exp_key] ||= MiqExpression.get_col_operators(:count).first
          else
            @edit[@expkey][:exp_count] = nil
            @edit[@expkey][:exp_key] = nil
            @edit[@expkey][:exp_value] = nil
          end
          @edit[@expkey][:alias] = nil
        end
        if params[:chosen_key] && params[:chosen_key] != @edit[@expkey][:exp_key] # Did the key change?
          @edit[@expkey][:exp_key] = params[:chosen_key]            # Save the key
        end

        if ui = params[:user_input]
          @edit[@expkey][:exp_value] = ui == "1" ? :user_input : nil
        end

      when "tag"
        if params[:chosen_tag] && params[:chosen_tag] != @edit[@expkey][:exp_tag] # Did the tag field change?
          unless params[:chosen_tag] == "<Choose>"
            @edit[@expkey][:exp_tag] = params[:chosen_tag]          # Save the field
          else
            @edit[@expkey][:exp_tag] = nil
          end
          @edit[@expkey][:exp_key] = @edit[@expkey][:exp_model] == "_display_filter_" ? "=" : "CONTAINS"
          @edit[@expkey][:exp_value] = nil                          # Clear out the tag value
          @edit[@expkey][:alias] = nil
        end

        if ui = params[:user_input]
          @edit[@expkey][:exp_value] = ui == "1" ? :user_input : nil
        end

      when "regkey"
        if params[:chosen_regkey] && params[:chosen_regkey] != @edit[@expkey][:exp_regkey].to_s # Did the regkey change?
          @edit[@expkey][:exp_regkey] = params[:chosen_regkey]      # Save the regkey
        end
        if params[:chosen_regval] && params[:chosen_regval] != @edit[@expkey][:exp_regval].to_s # Did the regkey change?
          @edit[@expkey][:exp_regval] = params[:chosen_regval]      # Save the regval
        end
        if params[:chosen_key] && params[:chosen_key] != @edit[@expkey][:exp_key] # Did the key change?
          @edit[@expkey][:exp_key] = params[:chosen_key]            # Save the key
          @edit[@expkey][:exp_value] = nil if [params[:chosen_key],@edit[@expkey][:exp_key]].include?("RUBY") # Clear the value if going to/from RUBY
        end
        exp_get_prefill_types                         # Get the field type

      when "find"
        if params[:chosen_field] && params[:chosen_field] != @edit[@expkey][:exp_field] # Did the field change?
          @edit[@expkey][:exp_field] = params[:chosen_field]        # Save the field
          @edit[@expkey][:exp_value] = nil                          # Clear the value
          @edit[:suffix] = nil                                      # Clear the suffix
          unless params[:chosen_field] == "<Choose>"
            @edit[@expkey][:exp_skey] = nil unless MiqExpression.get_col_operators(@edit[@expkey][:exp_field]).include?(@edit[@expkey][:exp_skey])  # Remove if not in list
            @edit[@expkey][:exp_skey] ||= MiqExpression.get_col_operators(@edit[@expkey][:exp_field]).first # Default to first operator
            @edit[@expkey][:exp_available_cfields] = Array.new      # Create the check fields pulldown array
            MiqExpression.miq_adv_search_lists(@edit[@expkey][:exp_model], :exp_available_finds).each do |af|
              unless af.last == @edit[@expkey][:exp_field]
                if af.last.split("-").first == @edit[@expkey][:exp_field].split("-").first
                  @edit[@expkey][:exp_available_cfields].push([af.first.split(":").last, af.last])
                end
              end
            end
            exp_get_prefill_types                                   # Get the field types
            process_datetime_expression_field(:val1, :exp_skey, :exp_value)
          else
            @edit[@expkey][:exp_field] = nil
            @edit[@expkey][:exp_skey] = nil
          end
          if (@edit[@expkey][:exp_cfield].present? && @edit[@expkey][:exp_field].present?) &&  # Clear expression check portion
             (@edit[@expkey][:exp_field] == @edit[@expkey][:exp_cfield] || # if find field matches check field
              @edit[@expkey][:exp_cfield].split("-").first != @edit[@expkey][:exp_field].split("-").first)  # or user chose a different table field
            @edit[@expkey][:exp_check] = "checkall"
            @edit[@expkey][:exp_cfield] = nil
            @edit[@expkey][:exp_ckey] = nil
            @edit[@expkey][:exp_cvalue] = nil
          end
          @edit[@expkey][:alias] = nil
        end

        if params[:chosen_skey] && params[:chosen_skey] != @edit[@expkey][:exp_skey]  # Did the key change?
          process_changed_expression(params, :chosen_skey, :exp_skey, :exp_value, :val1)
        end

        if params[:chosen_check] && params[:chosen_check] != @edit[@expkey][:exp_check] # Did check type change?
          @edit[@expkey][:exp_check] = params[:chosen_check]      # Save the check type
          @edit[@expkey][:exp_cfield] = nil                       # Clear the field
          # Clear the operator, unless checkcount, then set to =
          @edit[@expkey][:exp_ckey] = @edit[@expkey][:exp_check] == "checkcount" ? "=" : nil
          @edit[@expkey][:exp_cvalue] = nil                       # Clear the value
          @edit[:suffix2] = nil                                   # Clear the suffix
        end
        if params[:chosen_cfield] && params[:chosen_cfield] != @edit[@expkey][:exp_cfield]  # Did the check field change?
          @edit[@expkey][:exp_cfield] = params[:chosen_cfield]    # Save the check field
          @edit[@expkey][:exp_cvalue] = nil                       # Clear the value
          @edit[:suffix2] = nil                                   # Clear the suffix
          unless params[:chosen_cfield] == "<Choose>"
            @edit[@expkey][:exp_ckey] = nil unless MiqExpression.get_col_operators(@edit[@expkey][:exp_cfield]).include?(@edit[@expkey][:exp_ckey]) # Remove if not in list
            @edit[@expkey][:exp_ckey] ||= MiqExpression.get_col_operators(@edit[@expkey][:exp_cfield]).first  # Default to first operator
            exp_get_prefill_types                                 # Get the field types
            process_datetime_expression_field(:val2, :exp_ckey, :exp_cvalue)
          else
            @edit[@expkey][:exp_cfield] = nil
            @edit[@expkey][:exp_ckey] = nil
          end
        end

        if params[:chosen_ckey] && params[:chosen_ckey] != @edit[@expkey][:exp_ckey]  # Did the key change?
          process_changed_expression(params, :chosen_ckey, :exp_ckey, :exp_cvalue, :val2)
        end

        if params[:chosen_cvalue] && params[:chosen_cvalue] != @edit[@expkey][:exp_cvalue].to_s # Did the value change?
          @edit[@expkey][:exp_cvalue] = params[:chosen_cvalue]        # Save the value as a string
        end
      end

      # Check the value field for all exp types
      if params[:chosen_value] && params[:chosen_value] != @edit[@expkey][:exp_value].to_s  # Did the value change?
        if params[:chosen_value] == "<Choose>"
          @edit[@expkey][:exp_value] = nil
        else
          @edit[@expkey][:exp_value] = params[:chosen_value]        # Save the value as a string
        end
      end

      # Use alias checkbox
      if params.has_key?(:use_alias)
        if params[:use_alias] == "1"
          a = case @edit[@expkey][:exp_typ]
                when "field", "find"
                  MiqExpression.value2human(@edit[@expkey][:exp_field]).split(":").last
                when "tag"
                  MiqExpression.value2human(@edit[@expkey][:exp_tag]).split(":").last
                when "count"
                  MiqExpression.value2human(@edit[@expkey][:exp_count]).split(".").last
              end
          @edit[@expkey][:alias] = a.strip
        else
          @edit[@expkey].delete(:alias)
        end
      end

      # Check the alias field
      if params.has_key?(:alias) && params[:alias] != @edit[@expkey][:alias].to_s # Did the value change?
        if params[:alias].strip.blank?
          @edit[@expkey].delete(:alias)
        else
          @edit[@expkey][:alias] = params[:alias]
        end
      end

      # Check incoming date and time values
      # Copy FIND exp_skey to exp_key so following IFs work properly
      @edit[@expkey][:exp_key] = @edit[@expkey][:exp_skey] if @edit[@expkey][:exp_typ] == "FIND"
      process_datetime_selector("1_0", :exp_key)  # First date selector
      process_datetime_selector("1_1")            # 2nd date selector, only on FROM
      process_datetime_selector("2_0", :exp_ckey) # First date selector in FIND/CHECK
      process_datetime_selector("2_1")            # 2nd date selector, only on FROM

      # Check incoming FROM/THROUGH date/time choice values
      if params[:chosen_from_1]
        @edit[@expkey][:exp_value][0] = params[:chosen_from_1]
        @edit[@expkey][:val1][:through_choices] = exp_through_choices(params[:chosen_from_1])
        if (@edit[@expkey][:exp_typ] == "field" && @edit[@expkey][:exp_key] == EXP_FROM) ||
          (@edit[@expkey][:exp_typ] == "find" && @edit[@expkey][:exp_skey] == EXP_FROM)
          # If the through value is not in the through choices, set it to the first choice
          unless @edit[@expkey][:val1][:through_choices].include?(@edit[@expkey][:exp_value][1])
            @edit[@expkey][:exp_value][1] = @edit[@expkey][:val1][:through_choices].first
          end
        end
      end
      @edit[@expkey][:exp_value][1] = params[:chosen_through_1] if params[:chosen_through_1]

      if params[:chosen_from_2]
        @edit[@expkey][:exp_cvalue][0] = params[:chosen_from_2]
        @edit[@expkey][:val2][:through_choices] = exp_through_choices(params[:chosen_from_2])
        if @edit[@expkey][:exp_ckey] == EXP_FROM
          # If the through value is not in the through choices, set it to the first choice
          unless @edit[@expkey][:val2][:through_choices].include?(@edit[@expkey][:exp_cvalue][1])
            @edit[@expkey][:exp_cvalue][1] = @edit[@expkey][:val2][:through_choices].first
          end
        end
      end
      @edit[@expkey][:exp_cvalue][1] = params[:chosen_through_2] if params[:chosen_through_2]
    end

    # Check for changes in date format
    if params[:date_format_1] && @edit[@expkey][:exp_value].present?
      @edit[@expkey][:val1][:date_format] = params[:date_format_1]
      @edit[@expkey][:exp_value].collect! { |_| params[:date_format_1] == "s" ? nil : EXP_TODAY }
      @edit[@expkey][:val1][:through_choices] = exp_through_choices(@edit[@expkey][:exp_value][0]) if params[:date_format_1] == "r"
    end
    if params[:date_format_2] && @edit[@expkey][:exp_cvalue].present?
      @edit[@expkey][:val2][:date_format] = params[:date_format_2]
      @edit[@expkey][:exp_cvalue].collect! { |_| params[:date_format_2] == "s" ? nil : EXP_TODAY }
      @edit[@expkey][:val2][:through_choices] = exp_through_choices(@edit[@expkey][:exp_cvalue][0]) if params[:date_format_2] == "r"
    end

    # Check for suffixes changed
    %w(suffix suffix2).each do |key|
      params_key = "chosen_#{key}"
      @edit[key.to_sym] = MiqExpression::BYTE_FORMAT_WHITELIST[params[params_key]] if params[params_key]
    end

    # See if only a text value changed
    if params[:chosen_value] || params[:chosen_regkey] || params[:chosen_regval] ||
        params[:chosen_cvalue || params[:chosen_suffix]] || params[:alias]
      render :update do |page| end      # Render nothing back to the page
    else                                # Something else changed so update the exp_editor form
      render :update do |page|
        if @refresh_partial != nil
          if @refresh_div == "flash_msg_div"
            page.replace(@refresh_div + div_num, :partial=>@refresh_partial, :locals=>{:div_num=>div_num})
          end
        else
          page.replace("flash_msg_div" + div_num, :partial=>"layouts/flash_msg", :locals=>{:div_num=>div_num})
          page.replace("exp_atom_editor_div", :partial=>"layouts/exp_atom/editor", :locals => { :target_controller => params[:target_controller] })

          if [:date, :datetime].include?(@edit.fetch_path(@expkey, :val1, :type)) ||
              [:date, :datetime].include?(@edit.fetch_path(@expkey, :val2, :type))
            page << "miqBuildCalendar();"
          end

          page << "miq_val1_type = '#{@edit[@expkey][:val1][:type]}';" if @edit.fetch_path(@expkey,:val1,:type)
          page << "miq_val1_title = '#{@edit[@expkey][:val1][:title]}';" if @edit.fetch_path(@expkey,:val1,:type)
          page << "miq_val2_type = '#{@edit[@expkey][:val2][:type]}';" if @edit.fetch_path(@expkey,:val2,:type)
          page << "miq_val2_title = '#{@edit[@expkey][:val2][:title]}';" if @edit.fetch_path(@expkey,:val2,:type)

          page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
        end
      end
    end
  end
end
