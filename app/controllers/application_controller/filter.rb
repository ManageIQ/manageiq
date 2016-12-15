# Filter/search/expression methods included in application.rb
module ApplicationController::Filter
  extend ActiveSupport::Concern
  include MiqExpression::FilterSubstMixin
  include ApplicationController::ExpressionHtml

  # Handle buttons pressed in the expression editor
  def exp_button
    @edit = session[:edit]
    case params[:pressed]
    when "undo", "redo"
      @edit[@expkey][:expression] = @edit[@expkey].history.rewind(params[:pressed])
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
          exp.clear                                         # Remove all existing keys
          exp["???"] = "???"                                # Set new exp key
          @edit[:edit_exp] = copy_hash(exp)
          @edit[@expkey].update_from_exp_tree(exp)
        end
      else
        @edit[:edit_exp] = nil
      end
    when "discard"
      # Copy back the latest expression or empty expression, if nil
      @edit[@expkey].val1 = nil
      @edit[@expkey].val2 = nil
      @edit[@expkey][:expression] = @edit[:new][@expkey].nil? ? {"???" => "???"} : copy_hash(@edit[:new][@expkey])
      @edit.delete(:edit_exp)
    else
      add_flash(_("Button not yet implemented"), :error)
    end

    if flash_errors?
      javascript_flash(:flash_div_id => 'adv_search_flash')
    else
      if ["commit", "not", "remove"].include?(params[:pressed])
        copy = copy_hash(@edit[@expkey][:expression])
        copy.deep_delete :token
        @edit[:new][@expkey] = copy
        @edit[@expkey].history.push(@edit[:new][@expkey])
      end
      unless ["and", "or"].include?(params[:pressed]) # Unless adding an AND or OR token
        @edit[@expkey][:exp_token] = nil                        #   clear the current selected token
      end
      changed = (@edit[:new] != @edit[:current])
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        #       page.replace("form_expression_div", :partial=>"form_expression")
        if !@edit[:adv_search_open].nil?
          page.replace("adv_search_body", :partial => "layouts/adv_search_body")
          page.replace("adv_search_footer", :partial => "layouts/adv_search_footer")
        else
          page.replace("exp_editor_div", :partial => "layouts/exp_editor")
        end
        if ["not", "discard", "commit", "remove"].include?(params[:pressed])
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
    token = params[:token].to_i
    if token == @edit[@expkey][:exp_token] || # User selected same token as already selected
       (@edit[@expkey][:exp_token] && @edit[:edit_exp].key?("???")) # or new token in process
      javascript_flash
    else
      exp = exp_find_by_token(@edit[@expkey][:expression], token)
      @edit[:edit_exp] = copy_hash(exp)
      begin
        @edit[@expkey].update_from_exp_tree(exp)
      rescue => bang
        @exp_atom_errors = [_("There is an error in the selected expression element, perhaps it was imported or edited manually."),
                            _("This element should be removed and recreated or you can report the error to your %{product} administrator.") % {:product => I18n.t('product.name')},
                            _("Error details: %{message}") % {:message => bang}]
      end
      @edit[@expkey][:exp_token] = token
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page.replace("exp_editor_div", :partial => "layouts/exp_editor")
        page << "$('#exp_#{token}').css({'background-color': 'yellow'})"
        page << javascript_hide("exp_buttons_off")
        if exp.key?("not") || @parent_is_not
          page << javascript_hide("exp_buttons_on")
          page << javascript_show("exp_buttons_not")
        else
          page << javascript_hide("exp_buttons_not")
          page << javascript_show("exp_buttons_on")
        end

        page << ENABLE_CALENDAR if @edit[@expkey].calendar_needed?

        if @edit[@expkey][:exp_key] && @edit[@expkey][:exp_field]
          @edit[@expkey].render_values_to(page)
        end
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  # Handle items changed in the expression editor
  def exp_changed
    @edit = session[:edit]
    @edit[@expkey].update_from_expression_editor(params)
    # See if only a text value changed
    if params[:chosen_value] || params[:chosen_regkey] || params[:chosen_regval] ||
       params[:chosen_cvalue || params[:chosen_suffix]] || params[:alias]
      render :update do |page|
        page << javascript_prologue
      end
    elsif @refresh_div.to_s == 'flash_msg_div'
      javascript_flash
    else
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page.replace("exp_atom_editor_div", :partial => "layouts/exp_atom/editor")

        page << ENABLE_CALENDAR if @edit[@expkey].calendar_needed?
        @edit[@expkey].render_values_to(page)
        page << "miqSparkle(false);" # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  def adv_search_toggle
    @edit = session[:edit]

    # Rebuild the pulldowns if opening the search box
    @edit[@expkey].prefill_val_types unless @edit[:adv_search_open]

    render :update do |page|
      page << javascript_prologue
      if @edit[:adv_search_open] == true
        @edit[:adv_search_open] = false
        page << "$('#adv_search_img').prop('src', '#{ActionController::Base.helpers.image_path('toolbars/squashed-true.png')}')"
        page << javascript_hide("advsearchModal")
        page << javascript_hide("blocker_div")
      else
        @edit[:adv_search_open] = true
        page << "ManageIQ.explorer.clearSearchToggle(#{clear_search_status});"
        page.replace("adv_search_body", :partial => "layouts/adv_search_body")
        page.replace("adv_search_footer", :partial => "layouts/adv_search_footer")
        page << "$('#adv_search_img').prop('src', '#{ActionController::Base.helpers.image_path('toolbars/squashed-false.png')}')"
        page << ENABLE_CALENDAR if @edit[@expkey].calendar_needed?
        @edit[@expkey].render_values_to(page)
      end
      page << set_spinner_off
      # Rememeber this settting in the model settings
      if session.fetch_path(:adv_search, @edit[@expkey][:exp_model])
        session[:adv_search][@edit[@expkey][:exp_model]][:adv_search_open] = @edit[:adv_search_open]
      end
    end
  end

  # One of the form buttons was pressed on the advanced search panel
  def listnav_search_selected(id = nil)
    id ||= params[:id]
    @edit = session[:edit]
    @edit[:selected] = true # Set a flag, this is checked whether to load initial default or clear was clicked
    if id.to_i == 0
      clear_selected_search
    else
      load_selected_search(id)
    end

    unless @explorer
      respond_to do |format|
        format.js do
          if @quick_search_active
            quick_search_show
          else
            javascript_redirect :action => 'show_list' # Redirect to build the list screen
          end
        end
        format.html do
          redirect_to :action => 'show_list'  # Redirect to build the list screen
        end
      end
    end
  end

  def clear_selected_search
    @edit[:adv_search_applied] = nil
    @edit[@expkey][:expression] = {"???" => "???"}                            # Set as new exp element
    @edit[:new][@expkey] = copy_hash(@edit[@expkey][:expression])             # Copy to new exp
    @edit[@expkey].history.reset(@edit[@expkey][:expression])
    @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Rebuild the expression table
    @edit[@expkey][:selected] = {:id => 0}                                    # Save the last search loaded
    @edit[:adv_search_name] = nil                                             # Clear search name
    @edit[:adv_search_report] = nil                                           # Clear the report name
    session[:adv_search] ||= {}                                               # Create/reuse the adv search hash
    session[:adv_search][@edit[@expkey][:exp_model]] = copy_hash(@edit)       # Save by model name in settings
  end

  def load_selected_search(id)
    @expkey = :expression     # Reset to use default expression key
    @edit[:new] = {}
    s = MiqSearch.find(id.to_s)
    @edit[:new][@expkey] = s.filter.exp
    if s.quick_search?
      @quick_search_active = true
      @edit[:qs_prev_x_node] = x_node if @edit[:in_explorer] # Remember current tree node
      @edit[@expkey][:pre_qs_selected] = @edit[@expkey][:selected]            # Save previous selected search
      @edit[:qs_prev_adv_search_applied] = @edit[:adv_search_applied]         # Save any existing adv search
    end
    @edit[@expkey].select_filter(s)
    @edit[:new_search_name] = @edit[:adv_search_name] = @edit.fetch_path(@expkey, :selected, :description)
    @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
    @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Build the expression table
    @edit[@expkey].history.reset(@edit[@expkey][:expression])
    @edit[@expkey][:exp_token] = nil                                        # Clear the current selected token
    @edit[:adv_search_applied] = {}

    adv_search_set_text                                                 # Set search text filter suffix
    @edit[:adv_search_applied][:exp] = @edit[:new][@expkey]             # Save the expression to be applied
    @edit[@expkey].exp_token = nil                                      # Remove any existing atom being edited
    @edit[:adv_search_open] = false                                     # Close the adv search box
    session[:adv_search] ||= {}                                         # Create/reuse the adv search hash
    session[:adv_search][@edit[@expkey][:exp_model]] = copy_hash(@edit) # Save by model name in settings
  end

  def clear_default_search
    @edit[@expkey][:selected] = {:id => 0, :description => "All"}       # Save the last search loaded
    @edit[:adv_search_applied] = nil
    @edit[@expkey][:expression] = {"???" => "???"}                              # Set as new exp element
    @edit[:new][@expkey] = @edit[@expkey][:expression]                        # Copy to new exp
    @edit[@expkey].history.reset(@edit[@expkey][:expression])
    @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Rebuild the expression table
    # @edit[@expkey][:exp_last_loaded] = nil                                   # Clear the last search loaded
    @edit[:adv_search_name] = nil                                             # Clear search name
    @edit[:adv_search_report] = nil                                           # Clear the report name
  end

  def load_default_search(id)
    @edit ||= {}
    @expkey = :expression                                             # Reset to use default expression key
    @edit[@expkey] ||= Expression.new
    @edit[@expkey][:expression] = []                           # Store exps in an array
    @edit[:new] = {}
    @edit[:new][@expkey] = @edit[@expkey][:expression]                # Copy to new exp
    s = MiqSearch.find(id) unless id.zero?
    if s.nil? || s.search_key == "_hidden_" # search not found || admin changed default search to be hidden
      clear_default_search
    else
      @edit[:new][@expkey] = s.filter.exp
      @edit[@expkey].select_filter(s)
      @edit[:new_search_name] = @edit[:adv_search_name] = @edit[@expkey][:selected].nil? ? nil : @edit[@expkey][:selected][:description]
      @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Build the expression table
      @edit[@expkey].history.reset(@edit[@expkey][:expression])
      @edit[@expkey][:exp_token] = nil                                        # Clear the current selected token
      @edit[:adv_search_applied] = {}
      adv_search_set_text # Set search text filter suffix
      @edit[:adv_search_applied][:exp] = copy_hash(@edit[:new][@expkey])    # Save the expression to be applied
      @edit[@expkey].exp_token = nil                                        # Remove any existing atom being edited
    end
    @edit[:adv_search_open] = false                               # Close the adv search box
  end

  # One of the form buttons was pressed on the advanced search panel
  def adv_search_button
    @edit = session[:edit]
    @view = session[:view]

    # setting default to false
    @edit[:custom_search] = false

    case params[:button]
    when "saveit"
      if @edit[:new_search_name].nil? || @edit[:new_search_name] == ""
        add_flash(_("Search Name is required"), :error)
        params[:button] = "save" # Redraw the save screen
      else
        s = @edit[@expkey].build_search(@edit[:new_search_name], @edit[:search_type], session[:userid])
        s.filter = MiqExpression.new(@edit[:new][@expkey]) # Set the new expression
        if s.save
          add_flash(_("%{model} search \"%{name}\" was saved") %
            {:model => ui_lookup(:model => @edit[@expkey][:exp_model]),
             :name => @edit[:new_search_name]})
          @edit[@expkey].select_filter(s)
          @edit[:new_search_name] = @edit[:adv_search_name] = @edit[@expkey][:exp_last_loaded][:description]
          @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
          # Build the expression table
          @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])
          @edit[@expkey].history.reset(@edit[@expkey][:expression])
          # Clear the current selected token
          @edit[@expkey][:exp_token] = nil
        else
          s.errors.each do |field, msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          params[:button] = "save" # Redraw the save screen
        end
      end

    when "loadit"
      if @edit[@expkey][:exp_chosen_search]
        @edit[:selected] = true
        s = MiqSearch.find(@edit[@expkey][:exp_chosen_search].to_s)
        @edit[:new][@expkey] = s.filter.exp
        @edit[@expkey].select_filter(s, true)
        @edit[:search_type] = s[:search_type] == 'global' ? 'global' : nil
      elsif @edit[@expkey][:exp_chosen_report]
        r = MiqReport.find(@edit[@expkey][:exp_chosen_report].to_s)
        @edit[:new][@expkey] = r.conditions.exp
        @edit[@expkey][:exp_last_loaded] = nil                                # Clear the last search loaded
        @edit[:adv_search_report] = r.name                          # Save the report name
      end
      @edit[:new_search_name] = @edit[:adv_search_name] = @edit[@expkey][:exp_last_loaded].nil? ? nil : @edit[@expkey][:exp_last_loaded][:description]
      @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Build the expression table
      @edit[@expkey].history.reset(@edit[@expkey][:expression])
      @edit[@expkey][:exp_token] = nil                                        # Clear the current selected token
      add_flash(_("%{model} search \"%{name}\" was successfully loaded") %
        {:model => ui_lookup(:model => @edit[@expkey][:exp_model]), :name => @edit[:new_search_name]})

    when "delete"
      s = MiqSearch.find(@edit[@expkey][:selected][:id])              # Fetch the latest record
      id = s.id
      sname = s.description
      begin
        s.destroy                                                   # Delete the record
      rescue => bang
        add_flash(_("%{model} \"%{name}\": Error during 'delete': %{error_message}") %
          {:model => ui_lookup(:model => "MiqSearch"), :name => sname, :error_message => bang.message}, :error)
      else
        if @settings[:default_search] && @settings[:default_search][@edit[@expkey][:exp_model].to_s.to_sym] # See if a default search exists
          def_search = @settings[:default_search][@edit[@expkey][:exp_model].to_s.to_sym]
          if id.to_i == def_search.to_i
            user_settings = current_user.settings || {}
            user_settings[:default_search].delete(@edit[@expkey][:exp_model].to_s.to_sym)
            current_user.update_attributes(:settings => user_settings)
            @edit[:adv_search_applied] = nil          # clearing up applied search results
          end
        end
        add_flash(_("%{model} search \"%{name}\": Delete successful") %
          {:model => ui_lookup(:model => @edit[@expkey][:exp_model]), :name => sname})
        audit = {:event        => "miq_search_record_delete",
                 :message      => "[#{sname}] Record deleted",
                 :target_id    => id,
                 :target_class => "MiqSearch",
                 :userid       => session[:userid]}
        AuditEvent.success(audit)
      end

    when "reset"
      add_flash(_("The current search details have been reset"), :warning)

    when "apply"
      @edit[@expkey][:selected] = @edit[@expkey][:exp_last_loaded] # Save the last search loaded (saved)
      @edit[:adv_search_applied] ||= {}
      @edit[:adv_search_applied][:exp] = {}
      adv_search_set_text # Set search text filter suffix
      @edit[:selected] = true
      @edit[:adv_search_applied][:exp] = @edit[:new][@expkey]   # Save the expression to be applied
      @edit[@expkey].exp_token = nil                            # Remove any existing atom being edited
      @edit[:adv_search_open] = false                           # Close the adv search box
      if MiqExpression.quick_search?(@edit[:adv_search_applied][:exp])
        quick_search_show
        return
      else
        @edit[:adv_search_applied].delete(:qs_exp)            # Remove any active quick search
        session[:adv_search] ||= {}                     # Create/reuse the adv search hash
        session[:adv_search][@edit[@expkey][:exp_model]] = copy_hash(@edit) # Save by model name in settings
      end
      if @edit[:in_explorer]
        self.x_node = "root"                                      # Position on root node
        replace_right_cell
      else
        javascript_redirect :action => 'show_list' # redirect to build the list screen
      end
      return

    when "cancel"
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Rebuild the existing expression table
      @edit[@expkey].prefill_val_types
    end

    # Reset fields if delete or reset ran
    if ["delete", "reset"].include?(params[:button])
      @edit[@expkey][:expression] = {"???" => "???"}              # Set as new exp element
      @edit[:new][@expkey] = @edit[@expkey][:expression]        # Copy to new exp
      @edit[@expkey].history.reset(@edit[@expkey][:expression])
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Rebuild the expression table
      @edit[@expkey][:exp_last_loaded] = nil                    # Clear the last search loaded
      @edit[:adv_search_name] = nil                             # Clear search name
      @edit[:adv_search_report] = nil                           # Clear the report name
      @edit[@expkey][:selected] = nil                           # Clear selected search
    elsif params[:button] == "save"
      @edit[:search_type] = nil unless @edit.key?(:search_type)
    end

    if ["delete", "saveit"].include?(params[:button])
      if @edit[:in_explorer]
        if "cs_filter_tree" == x_active_tree.to_s
          build_configuration_manager_tree(:cs_filter, x_active_tree)
        else
          tree_type = x_active_tree.to_s.sub(/_tree/, '').to_sym
          builder = TreeBuilder.class_for_type(tree_type)
          tree = builder.new(x_active_tree, tree_type, @sb)
        end
      elsif %w(ems_cloud ems_infra).include?(@layout)
        build_listnav_search_list(@view.db)
      else
        build_listnav_search_list(@edit[@expkey][:exp_model])
      end
    end

    render :update do |page|
      page << javascript_prologue
      if ["load", "save"].include?(params[:button])
        page.replace("adv_search_body", :partial => "layouts/adv_search_body", :locals => {:mode => params[:button]})
        page.replace("adv_search_footer", :partial => "layouts/adv_search_footer",
                                          :locals  => {:mode => params[:button]})
      else
        @edit[@expkey][:exp_chosen_report] = nil
        @edit[@expkey][:exp_chosen_search] = nil
        page.replace("adv_search_body", :partial => "layouts/adv_search_body")
        page.replace("adv_search_footer", :partial => "layouts/adv_search_footer")
      end

      if ["delete", "saveit"].include?(params[:button])
        if @edit[:in_explorer]
          tree_name = x_active_tree.to_s
          if "cs_filter_tree" == tree_name
            page.replace_html("#{tree_name}_div", :partial => "provider_foreman/#{tree_name}")
          else
            page.replace_html("#{tree_name}_div", :partial => "shared/tree", :locals => {
              :tree => tree,
              :name => tree_name
            })
          end
        else
          page.replace(:listnav_div, :partial => "layouts/listnav")
        end
      end
    end
  end

  # One of the load choices was selected on the advanced search load panel
  def adv_search_load_choice
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
      page << javascript_prologue
      page.replace("adv_search_body", :partial => "layouts/adv_search_body", :locals => {:mode => 'load'})
      page.replace("adv_search_footer", :partial => "layouts/adv_search_footer", :locals => {:mode => 'load'})
    end
  end

  # Character typed into search name field
  def adv_search_name_typed
    @edit = session[:edit]
    @edit[:new_search_name] = params[:search_name] if params[:search_name]
    @edit[:search_type] = params[:search_type].to_s == "1" ? "global" : nil if params[:search_type]
    render :update do |page|
      page << javascript_prologue
    end
  end

  # Clear the applied search
  def adv_search_clear
    respond_to do |format|
      format.js do
        @explorer = true
        if x_active_tree.to_s =~ /_filter_tree$/ &&
           !["Vm", "MiqTemplate"].include?(TreeBuilder.get_model_for_prefix(@nodetype))
          search_id = 0
          if x_active_tree == :cs_filter_tree
            adv_search_build("ConfiguredSystem")
          else
            adv_search_build(vm_model_from_active_tree(x_active_tree))
          end
          session[:edit] = @edit              # Set because next method will restore @edit from session
        end
        listnav_search_selected(search_id)  # Clear or set the adv search filter
        self.x_node = "root"
        replace_right_cell
      end
      format.html do
        @edit = session[:edit]
        @view = session[:view]
        @edit[:adv_search_applied] = nil
        @edit[:expression][:exp_last_loaded] = nil
        session[:adv_search] ||= {}                   # Create/reuse the adv search hash
        session[:adv_search][@edit[@expkey][:exp_model]] = copy_hash(@edit) # Save by model name in settings
        if @settings[:default_search] && @settings[:default_search][@view.db.to_s.to_sym] && @settings[:default_search][@view.db.to_s.to_sym].to_i != 0
          s = MiqSearch.find(@settings[:default_search][@view.db.to_s.to_sym])
          @edit[@expkey].select_filter(s)
          @edit[:selected] = false
        else
          @edit[@expkey][:selected] = {:id => 0}
          @edit[:selected] = true     # Set a flag, this is checked whether to load initial default or clear was clicked
        end
        redirect_to(:action => "show_list")
      end
      format.any { head :not_found }  # Anything else, just send 404
    end
  end

  # Save default search
  def save_default_search
    @edit = session[:edit]
    @view = session[:view]
    cols_key = @view.scoped_association.nil? ? @view.db.to_sym : (@view.db + "-" + @view.scoped_association).to_sym
    if params[:id]
      if params[:id] != "0"
        s = MiqSearch.find_by(:id => params[:id])
        if s.nil?
          add_flash(_("The selected Filter record was not found"), :error)
        elsif s.quick_search?
          add_flash(_("The selected Filter can not be set as Default because it requires user input"), :error)
        end
      end
      if @flash_array.blank?
        @settings[:default_search] ||= {}
        @settings[:default_search][cols_key] ||= {}
        @settings[:default_search][cols_key] = params[:id].to_i

        user_settings = current_user.settings || {}
        user_settings[:default_search] ||= {}
        user_settings[:default_search][cols_key] ||= {}
        user_settings[:default_search][cols_key] = @settings[:default_search][cols_key]
        current_user.update_attributes(:settings => user_settings)
      end
    end
    build_listnav_search_list(@view.db) if @flash_array.blank?

    if @flash_array.blank?
      render :update do |page|
        page << javascript_prologue
        page.replace(:listnav_div, :partial => "layouts/listnav")
        page.replace(:flash_msg_div, :partial => "layouts/flash_msg")
        page << "miqSparkleOff();"
      end
    else
      javascript_flash
    end
  end

  def quick_search_load_params_to_tokens
    # Capture any value/suffix entered
    params.each do |key, value|
      token_key = key.to_s.split("_").last.to_i
      if key.to_s.starts_with?("value_")
        @edit[:qs_tokens][token_key][:value] = value
      elsif key.to_s.starts_with?("suffix_")
        @edit[:qs_tokens][token_key][:suffix] = value
      end
    end
  end
  private :quick_search_load_params_to_tokens

  def quick_search_apply_click
    @edit[:adv_search_applied][:qs_exp] = copy_hash(@edit[:adv_search_applied][:exp] || {})
    exp_replace_qs_tokens(@edit[:adv_search_applied][:qs_exp], @edit[:qs_tokens])
    exp_remove_tokens(@edit[:adv_search_applied][:qs_exp])
    session[:adv_search] ||= {}
    session[:adv_search][@edit[@expkey][:exp_model]] = copy_hash(@edit) # Save by model name in settings
    if @edit[:in_explorer]
      replace_right_cell
    else
      javascript_redirect :action => 'show_list'
    end
  end
  private :quick_search_apply_click

  def quick_search_cancel_click
    @edit[@expkey][:selected] = @edit[@expkey][:pre_qs_selected]                # Restore previous selected search
    @edit[:adv_search_applied] = @edit[:qs_prev_adv_search_applied]             # Restore previous adv search
    @edit[:adv_search_applied] = nil unless @edit.fetch_path(:adv_search_applied, :exp) # Remove adv search if no prev expression
    self.x_node = @edit[:qs_prev_x_node] if @edit[:in_explorer]                   # Restore previous exp tree node
    session[:adv_search] ||= {}
    session[:adv_search][@edit[@expkey][:exp_model]] = copy_hash(@edit) # Save by model name in settings

    render :update do |page|
      page << javascript_prologue
      page << "miqTreeActivateNodeSilently('#{x_active_tree}', '#{x_node}');" if @edit[:in_explorer]
      page << "$('#quicksearchbox').modal('hide');"
      page << "miqSparkle(false);"
    end
  end
  private :quick_search_cancel_click

  # Handle input from the quick search box
  def quick_search
    @quick_search_active = true
    @edit = session[:edit]  # Keep @edit alive as it contains all search info

    quick_search_load_params_to_tokens

    case params[:button]
    when 'apply'
      quick_search_apply_click
    when 'cancel'
      quick_search_cancel_click
    else
      any_empty = @edit[:qs_tokens].values.any? { |v| v[:value].to_s.empty? }
      render :update do |page|
        page << javascript_prologue
        page << javascript_for_miq_button_visibility(!any_empty, 'quick_search')
      end
    end
  end

  private

  # Popup/open the quick search box
  def quick_search_show
    @exp_token           = nil
    @quick_search_active = true
    @qs_exp_table        = exp_build_table(@edit[:adv_search_applied][:exp], true)
    @edit[:qs_tokens]    = create_tokens(@qs_exp_table, @edit[:adv_search_applied][:exp])

    render :update do |page|
      page << javascript_prologue
      page.replace(:user_input_filter, :partial => "layouts/user_input_filter")
      page << "$('#advsearchModal').modal('hide');"
      page << "$('#quicksearchbox').modal('show');"
      page << "miqSparkle(false);"
    end
  end

  # Set advanced search filter text
  def adv_search_set_text
    if @edit[@expkey].history.idx == 0                          # Are we pointing at the first exp
      if @edit[:adv_search_name]
        @edit[:adv_search_applied][:text] = _(" - Filtered by \"%{text}\"") % {:text => @edit[:adv_search_name]}
      else
        @edit[:adv_search_applied][:text] = _(" - Filtered by \"%{text}\" report") %
                                              {:text => @edit[:adv_search_report]}
      end
    else
      @edit[:custom_search] = true
      @edit[:adv_search_applied][:text] = _(" - Filtered by custom search")
    end
  end

  # Remove :token keys from an expression before setting in a record
  def exp_remove_tokens(exp)
    if exp.kind_of?(Array)         # Is this and AND or OR
      exp.each do |e|           #   yes, check each array item
        exp_remove_tokens(e)    # Remove tokens from children
      end
    else
      exp.delete(:token)        # Remove :token key from any expression hash

      # Chase down any other tokens in child expressions
      if exp["not"]
        exp_remove_tokens(exp["not"])
      elsif exp["and"]
        exp_remove_tokens(exp["and"])
      elsif exp["or"]
        exp_remove_tokens(exp["or"])
      end

    end
  end

  # Add a joiner (and/or) above an expression
  def exp_add_joiner(exp, token, joiner)
    if exp[:token] && exp[:token] == token            # If the token matches
      exp.keys.each do |key|                          # Find the key
        if key == :token
          exp.delete(key)                             # Remove the :token key
        else
          exp[joiner] = [{key => exp[key]}]             # Chain in the current key under the joiner array
          exp.delete(key)                             # Remove the current key
          exp[joiner].push("???" => "???")            # Add in the new key under the joiner
        end
      end
      return
    else
      exp.each do |key, _value|                        # Go thru the next level down
        next if key == :token                         # Skip the :token key
        case key.upcase
        when "AND", "OR"                              # If AND or OR, check all array items
          if key.downcase != joiner                   # Does the and/or match the joiner?
            exp[key].each_with_index do |item, _idx|   # No,
              exp_add_joiner(item, token, joiner)     #   check the lower expressions
            end
          else
            exp[key].each_with_index do |item, idx|   # Yes,
              if item[:token] && item[:token] == token  # Found the match
                exp[key].insert(idx + 1, "???" => "???")  # Add in the new key hash
              else
                exp_add_joiner(item, token, joiner)   # No match, check the lower expressions
              end
            end
          end
        when "NOT"                                    # If NOT, check the sub-hash
          exp_add_joiner(exp[key], token, joiner)     # Check lower for the matching token
        end
      end
    end
  end

  # Add a NOT above an expression
  def exp_add_not(exp, token)
    if exp[:token] && exp[:token] == token            # If the token matches
      exp.keys.each do |key|                          # Find the key
        next if key == :token                         # Skip the :token key
        next if exp[key].nil?                       # Check for the key already gone
        exp["not"] = {}                         # Create the "not" hash
        exp["not"][key] = exp[key]                    # copy the found key's value down into the "not" hash
        exp.delete(key)                               # Remove the existing key
      end
    else
      exp.each do |key, _value|                        # Go thru the next level down
        next if key == :token                         # Skip the :token key
        case key.upcase
        when "AND", "OR"                              # If AND or OR, check all array items
          exp[key].each_with_index do |item, _idx|
            exp_add_not(item, token)                  # See if the NOT applies each level down
          end
        when "NOT"                                    # If NOT, check the sub-hash
          exp_add_not(exp[key], token)                # See if the NOT applies to the next level down
        end
      end
    end
  end

  # Update the current expression part with the latest changes
  def exp_commit(token)
    exp = exp_find_by_token(@edit[@expkey][:expression], token.to_i)
    case @edit[@expkey][:exp_typ]
    when "field"
      if @edit[@expkey][:exp_field].nil?
        add_flash(_("A field must be chosen to commit this expression element"), :error)
      elsif @edit[@expkey][:exp_value] != :user_input &&
            e = MiqExpression.atom_error(@edit[@expkey][:exp_field],
                                         @edit[@expkey][:exp_key],
                                         @edit[@expkey][:exp_value].kind_of?(Array) ?
                                           @edit[@expkey][:exp_value] :
                                           (@edit[@expkey][:exp_value].to_s + Expression.prefix_by_dot(@edit[@expkey].val1_suffix))
                                        )
        add_flash(_("Field Value Error: %{msg}") % {:msg => e}, :error)
      else
        # Change datetime and date values from single element arrays to text string
        if [:datetime, :date].include?(@edit[@expkey][:val1][:type])
          @edit[@expkey][:exp_value] = @edit[@expkey][:exp_value].first.to_s if @edit[@expkey][:exp_value].length == 1
        end

        exp.delete(@edit[@expkey][:exp_orig_key])                     # Remove the old exp fields
        exp[@edit[@expkey][:exp_key]] = {}                        # Add in the new key
        exp[@edit[@expkey][:exp_key]]["field"] = @edit[@expkey][:exp_field]     # Set the field
        unless @edit[@expkey][:exp_key].include?("NULL") || @edit[@expkey][:exp_key].include?("EMPTY")  # Check for "IS/IS NOT NULL/EMPTY"
          exp[@edit[@expkey][:exp_key]]["value"] = @edit[@expkey][:exp_value]   #   else set the value
          unless exp[@edit[@expkey][:exp_key]]["value"] == :user_input
            exp[@edit[@expkey][:exp_key]]["value"] += Expression.prefix_by_dot(@edit[@expkey].val1_suffix)
          end
        end
        exp[@edit[@expkey][:exp_key]]["alias"] = @edit[@expkey][:alias] if @edit.fetch_path(@expkey, :alias)
      end
    when "count"
      if @edit[@expkey][:exp_value] != :user_input &&
         e = MiqExpression.atom_error(:count, @edit[@expkey][:exp_key], @edit[@expkey][:exp_value])
        add_flash(_("Field Value Error: %{msg}") % {:msg => e}, :error)
      else
        exp.delete(@edit[@expkey][:exp_orig_key])                     # Remove the old exp fields
        exp[@edit[@expkey][:exp_key]] = {}                        # Add in the new key
        exp[@edit[@expkey][:exp_key]]["count"] = @edit[@expkey][:exp_count]     # Set the count table
        exp[@edit[@expkey][:exp_key]]["value"] = @edit[@expkey][:exp_value]     # Set the value
        exp[@edit[@expkey][:exp_key]]["alias"] = @edit[@expkey][:alias] if @edit.fetch_path(@expkey, :alias)
      end
    when "tag"
      if @edit[@expkey][:exp_tag].nil?
        add_flash(_("A tag category must be chosen to commit this expression element"), :error)
      elsif @edit[@expkey][:exp_value].nil?
        add_flash(_("A tag value must be chosen to commit this expression element"), :error)
      else
        if exp.present?
          exp.delete(@edit[@expkey][:exp_orig_key])                     # Remove the old exp fields
          exp[@edit[@expkey][:exp_key]] = {}                        # Add in the new key
          exp[@edit[@expkey][:exp_key]]["tag"] = @edit[@expkey][:exp_tag]         # Set the tag
          exp[@edit[@expkey][:exp_key]]["value"] = @edit[@expkey][:exp_value]     # Set the value
          exp[@edit[@expkey][:exp_key]]["alias"] = @edit[@expkey][:alias] if @edit.fetch_path(@expkey, :alias)
        end
      end
    when "regkey"
      if @edit[@expkey][:exp_regkey].blank?
        add_flash(_("A registry key name must be entered to commit this expression element"), :error)
      elsif @edit[@expkey][:exp_regval].blank? && @edit[@expkey][:exp_key] != "KEY EXISTS"
        add_flash(_("A registry value name must be entered to commit this expression element"), :error)
      elsif @edit[@expkey][:exp_key].include?("REGULAR EXPRESSION") && e = MiqExpression.atom_error(:regexp, @edit[@expkey][:exp_key], @edit[@expkey][:exp_value])
        add_flash(_("Registry Value Error: %{msg}") % {:msg => e}, :error)
      else
        exp.delete(@edit[@expkey][:exp_orig_key])                     # Remove the old exp fields
        exp[@edit[@expkey][:exp_key]] = {}                        # Add in the new key
        exp[@edit[@expkey][:exp_key]]["regkey"] = @edit[@expkey][:exp_regkey]   # Set the key name
        unless  @edit[@expkey][:exp_key].include?("KEY EXISTS")
          exp[@edit[@expkey][:exp_key]]["regval"] = @edit[@expkey][:exp_regval] # Set the value name
        end
        unless  @edit[@expkey][:exp_key].include?("NULL") || # Check for "IS/IS NOT NULL/EMPTY" or "EXISTS"
                @edit[@expkey][:exp_key].include?("EMPTY") ||
                @edit[@expkey][:exp_key].include?("EXISTS")
          exp[@edit[@expkey][:exp_key]]["value"] = @edit[@expkey][:exp_value]   #   else set the data value
        end
      end
    when "find"
      if @edit[@expkey][:exp_field].nil?
        add_flash(_("A find field must be chosen to commit this expression element"), :error)
      elsif ["checkall", "checkany"].include?(@edit[@expkey][:exp_check]) &&
            @edit[@expkey][:exp_cfield].nil?
        add_flash(_("A check field must be chosen to commit this expression element"), :error)
      elsif @edit[@expkey][:exp_check] == "checkcount" &&
            (@edit[@expkey][:exp_cvalue].nil? || is_integer?(@edit[@expkey][:exp_cvalue]) == false)
        add_flash(_("The check count value must be an integer to commit this expression element"), :error)
      elsif e = MiqExpression.atom_error(@edit[@expkey][:exp_field],
                                         @edit[@expkey][:exp_skey],
                                         @edit[@expkey][:exp_value].kind_of?(Array) ?
                                           @edit[@expkey][:exp_value] :
                                           (@edit[@expkey][:exp_value].to_s + Expression.prefix_by_dot(@edit[@expkey].val1_suffix))
                                        )
        add_flash(_("Find Value Error: %{msg}") % {:msg => e}, :error)
      elsif e = MiqExpression.atom_error(@edit[@expkey][:exp_check] == "checkcount" ? :count : @edit[@expkey][:exp_cfield],
                                         @edit[@expkey][:exp_ckey],
                                         @edit[@expkey][:exp_cvalue].kind_of?(Array) ?
                                           @edit[@expkey][:exp_cvalue] :
                                           (@edit[@expkey][:exp_cvalue].to_s + Expression.prefix_by_dot(@edit[@expkey].val2_suffix))
                                        )
        add_flash(_("Check Value Error: %{msg}") % {:msg => e}, :error)
      else
        # Change datetime and date values from single element arrays to text string
        if [:datetime, :date].include?(@edit[@expkey][:val1][:type])
          @edit[@expkey][:exp_value] = @edit[@expkey][:exp_value].first.to_s if @edit[@expkey][:exp_value].length == 1
        end
        if @edit[@expkey][:val2][:type] && [:datetime, :date].include?(@edit[@expkey][:val2][:type])
          @edit[@expkey][:exp_cvalue] = @edit[@expkey][:exp_cvalue].first.to_s if @edit[@expkey][:exp_cvalue].length == 1
        end

        exp.delete(@edit[@expkey][:exp_orig_key])                     # Remove the old exp fields
        exp[@edit[@expkey][:exp_key]] = {}                        # Add in the new key
        exp[@edit[@expkey][:exp_key]]["search"] = {}              # Create the search hash
        skey = @edit[@expkey][:exp_skey]
        exp[@edit[@expkey][:exp_key]]["search"][skey] = {}        # Create the search operator hash
        exp[@edit[@expkey][:exp_key]]["search"][skey]["field"] = @edit[@expkey][:exp_field] # Set the search field
        unless skey.include?("NULL") || skey.include?("EMPTY")  # Check for "IS/IS NOT NULL/EMPTY"
          exp[@edit[@expkey][:exp_key]]["search"][skey]["value"] = @edit[@expkey][:exp_value] #   else set the value
          exp[@edit[@expkey][:exp_key]]["search"][skey]["value"] += Expression.prefix_by_dot(@edit[@expkey].val1_suffix)
        end
        chk = @edit[@expkey][:exp_check]
        exp[@edit[@expkey][:exp_key]][chk] = {}                 # Create the check hash
        ckey = @edit[@expkey][:exp_ckey]
        exp[@edit[@expkey][:exp_key]][chk][ckey] = {}           # Create the check operator hash
        if @edit[@expkey][:exp_check] == "checkcount"
          exp[@edit[@expkey][:exp_key]][chk][ckey]["field"] = "<count>" # Indicate count is being checked
        else
          exp[@edit[@expkey][:exp_key]][chk][ckey]["field"] = @edit[@expkey][:exp_cfield] # Set the check field
        end
        unless ckey.include?("NULL") || ckey.include?("EMPTY")  # Check for "IS/IS NOT NULL/EMPTY"
          exp[@edit[@expkey][:exp_key]][chk][ckey]["value"] = @edit[@expkey][:exp_cvalue] #   else set the value
          exp[@edit[@expkey][:exp_key]][chk][ckey]["value"] += Expression.prefix_by_dot(@edit[@expkey].val2_suffix)
        end
        exp[@edit[@expkey][:exp_key]]["search"][skey]["alias"] = @edit[@expkey][:alias] if @edit.fetch_path(@expkey, :alias)
      end
    else
      add_flash(_("Select an expression element type"), :error)
    end
  end

  # Remove an expression part based on the token
  def exp_remove(exp, token)
    if exp[:token] && exp[:token] == token              # If the token matches
      return true                                       #   Tell caller to remove me
    else
      keepkey, keepval, deletekey = nil                 # Holders for key, value pair to keep and key to delete
      exp.each do |key, _value|                          # Go thru each exp element
        next if key == :token                           # Skip the :token keys
        case key.upcase
        when "AND", "OR"                                # If AND or OR
          exp[key].each_with_index do |item, idx|       #   check all array items
            if exp_remove(item, token) == true          # See if this part should be removed
              if item.key?("not")                   # The item to remove is a NOT
                exp[key].insert(idx + 1, item["not"])      # Rechain the NOT child into the array
                exp[key].delete_at(idx)                 # Remove the NOT item
              else                                      # Item to remove is other than a NOT
                exp[key].delete_at(idx)                 # Remove it from the array
                if exp[key].length == 1                 # If only 1 part left
                  exp[key][0].each do |k, _v|             # Find the key that's not :token
                    next if k == :token                 # Skip the :token key
                    keepkey = k                         # Hang on to the key to keep
                    keepval = exp[key][0][k]            #   and the value to keep
                    deletekey = key                     #   and the key to delete
                    break
                  end
                end
              end
            end
          end
        when "NOT"                                      # If NOT, check the sub-hash
          if exp_remove(exp[key], token) == true        # Next lower hash is to be removed
            exp.delete("not")                           # Remove the NOT hash
            return true                                 # Tell caller to remove me
          end
        else
          return false
        end
      end
      exp[keepkey] = keepval if keepkey                 # Copy the key value to keep up 1 level
      exp.delete(deletekey)                             # Remove the AND or OR hash
      return false                                      # Done removing item, return
    end
  end

  # Build advanced search expression
  def adv_search_build(model)
    # Restore @edit hash if it's saved in @settings
    @expkey = :expression                                               # Reset to use default expression key
    if session[:adv_search] && session[:adv_search][model.to_s]
      @edit = copy_hash(session[:adv_search][model.to_s])
      # default search doesnt exist or if it is marked as hidden
      if @edit && @edit[:expression] && !@edit[:expression][:selected].blank? &&
         !MiqSearch.exists?(@edit[:expression][:selected][:id])
        clear_default_search
      elsif @edit && @edit[:expression] && !@edit[:expression][:selected].blank?
        s = MiqSearch.find(@edit[:expression][:selected][:id])
        clear_default_search if s.search_key == "_hidden_"
      end
      @edit.delete(:exp_token)                                          # Remove any existing atom being edited
    else                                                                # Create new exp fields
      @edit = {}
      @edit[@expkey] ||= Expression.new
      @edit[@expkey][:expression] = []                           # Store exps in an array
      @edit[@expkey][:expression] = {"???" => "???"}                      # Set as new exp element
      @edit[@expkey][:use_mytags] = true                                # Include mytags in tag search atoms
      @edit[:custom_search] = false                                     # setting default to false
      @edit[:new] = {}
      @edit[:new][@expkey] = @edit[@expkey][:expression]                # Copy to new exp
      @edit[@expkey].history.reset(@edit[@expkey][:expression])
      @edit[:adv_search_open] = false
      @edit[@expkey][:exp_model] = model.to_s
    end
    @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Build the table to display the exp
    @edit[:in_explorer] = @explorer # Remember if we're in an explorer

    if @hist && @hist[:qs_exp] # Override qs exp if qs history button was pressed
      @edit[:adv_search_applied] = {:text => @hist[:text], :qs_exp => @hist[:qs_exp]}
      session[:adv_search][model.to_s] = copy_hash(@edit) # Save updated adv_search options
    end
  end

  def build_listnav_search_list(db)
    @settings[:default_search] = current_user.settings[:default_search]  # Get the user's default search settings again, incase default search was deleted
    @default_search = MiqSearch.find(@settings[:default_search][db.to_sym].to_s) if @settings[:default_search] && @settings[:default_search][db.to_sym] && @settings[:default_search][db.to_sym] != 0 && MiqSearch.exists?(@settings[:default_search][db.to_sym])
    temp = MiqSearch.new
    temp.description = _("ALL")
    temp.id = 0
    @def_searches = MiqSearch.where(:db => [db, db.constantize.to_s]).visible_to_all.sort_by { |s| s.description.downcase }
    @def_searches = @def_searches.unshift(temp) unless @def_searches.empty?
    @my_searches = MiqSearch.where(:search_type => "user", :search_key => session[:userid], :db => [db, db.constantize.to_s]).sort_by { |s| s.description.downcase }
  end

  ENABLE_CALENDAR = "miqBuildCalendar();".freeze
end
