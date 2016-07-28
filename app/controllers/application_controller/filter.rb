# Filter/search/expression methods included in application.rb
module ApplicationController::Filter
  extend ActiveSupport::Concern
  included do
    helper_method :calendar_needed?  # because it is being called inside a render block
  end

  include MiqExpression::FilterSubstMixin
  include ApplicationController::ExpressionHtml

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
          exp.clear                                         # Remove all existing keys
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
      @edit[@expkey][:expression] = @edit[:new][@expkey].nil? ? {"???" => "???"} : copy_hash(@edit[:new][@expkey])
      @edit.delete(:edit_exp)
    else
      add_flash(_("Button not yet implemented"), :error)
    end

    if flash_errors?
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div#{div_num}", :partial => "layouts/flash_msg", :locals => {:div_num => div_num})
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
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div#{div_num}", :partial => "layouts/flash_msg", :locals => {:div_num => div_num})
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
    div_num = @edit[:flash_div_num] ? @edit[:flash_div_num] : ""
    token = params[:token].to_i
    if token == @edit[@expkey][:exp_token] || # User selected same token as already selected
       (@edit[@expkey][:exp_token] && @edit[:edit_exp].key?("???")) # or new token in process
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div#{div_num}", :partial => "layouts/flash_msg", :locals => {:div_num => div_num})
      end
    else
      exp = exp_find_by_token(@edit[@expkey][:expression], token)
      @edit[:edit_exp] = copy_hash(exp)
      begin
        exp_set_fields(@edit[:edit_exp])
      rescue StandardError => bang
        @exp_atom_errors = [_("There is an error in the selected expression element, perhaps it was imported or edited manually."),
                            _("This element should be removed and recreated or you can report the error to your CFME administrator."),
                            _("Error details: %{message}") % {:message => bang}]
      end
      @edit[@expkey][:exp_token] = token
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div#{div_num}", :partial => "layouts/flash_msg", :locals => {:div_num => div_num})
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

        page << ENABLE_CALENDAR if calendar_needed?

        if @edit[@expkey][:exp_key] && @edit[@expkey][:exp_field]
          if @edit[@expkey][:val1][:type]
            page << "ManageIQ.expEditor.first.type = '#{@edit[@expkey][:val1][:type]}';"
            page << "ManageIQ.expEditor.first.title = '#{@edit[@expkey][:val1][:title]}';"
          end
          if @edit[@expkey][:val2][:type]
            page << "ManageIQ.expEditor.second.type = '#{@edit[@expkey][:val2][:type]}';"
            page << "ManageIQ.expEditor.second.title = '#{@edit[@expkey][:val2][:title]}';"
          end
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
            if @edit[@expkey][:exp_model] != "_display_filter_" && MiqExpression::Field.parse(@edit[@expkey][:exp_field]).plural?
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
        # Did the key change?, Save the key
        @edit[@expkey][:exp_key] = params[:chosen_key] if params[:chosen_key] && params[:chosen_key] != @edit[@expkey][:exp_key]
        exp_get_prefill_types                         # Get the field type

      when "find"
        if params[:chosen_field] && params[:chosen_field] != @edit[@expkey][:exp_field] # Did the field change?
          @edit[@expkey][:exp_field] = params[:chosen_field]        # Save the field
          @edit[@expkey][:exp_value] = nil                          # Clear the value
          @edit[:suffix] = nil                                      # Clear the suffix
          unless params[:chosen_field] == "<Choose>"
            @edit[@expkey][:exp_skey] = nil unless MiqExpression.get_col_operators(@edit[@expkey][:exp_field]).include?(@edit[@expkey][:exp_skey])  # Remove if not in list
            @edit[@expkey][:exp_skey] ||= MiqExpression.get_col_operators(@edit[@expkey][:exp_field]).first # Default to first operator
            @edit[@expkey][:exp_available_cfields] = []      # Create the check fields pulldown array
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
          if (@edit[@expkey][:exp_cfield].present? && @edit[@expkey][:exp_field].present?) && # Clear expression check portion
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
      if params.key?(:use_alias)
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
      if params.key?(:alias) && params[:alias] != @edit[@expkey][:alias].to_s # Did the value change?
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
      render :update do |page|
        page << javascript_prologue
      end
    else                                # Something else changed so update the exp_editor form
      render :update do |page|
        page << javascript_prologue
        if !@refresh_partial.nil?
          if @refresh_div == "flash_msg_div"
            page.replace(@refresh_div + div_num, :partial => @refresh_partial, :locals => {:div_num => div_num})
          end
        else
          page.replace("flash_msg_div" + div_num, :partial => "layouts/flash_msg", :locals => {:div_num => div_num})
          page.replace("exp_atom_editor_div", :partial => "layouts/exp_atom/editor")

          page << ENABLE_CALENDAR if calendar_needed?
          if @edit.fetch_path(@expkey, :val1, :type)
            page << "ManageIQ.expEditor.first.type = '#{@edit[@expkey][:val1][:type]}';"
            page << "ManageIQ.expEditor.first.title = '#{@edit[@expkey][:val1][:title]}';"
          end
          if @edit.fetch_path(@expkey, :val2, :type)
            page << "ManageIQ.expEditor.second.type = '#{@edit[@expkey][:val2][:type]}';"
            page << "ManageIQ.expEditor.second.title = '#{@edit[@expkey][:val2][:title]}';"
          end
          page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
        end
      end
    end
  end

  def adv_search_toggle
    @edit = session[:edit]

    # Rebuild the pulldowns if opening the search box
    adv_search_build_lists unless @edit[:adv_search_open]
    exp_get_prefill_types unless @edit[:adv_search_open]

    render :update do |page|
      page << javascript_prologue
      if @edit[:adv_search_open] == true
        @edit[:adv_search_open] = false
        page << "$('#adv_search_img').prop('src', '#{ActionController::Base.helpers.image_path('toolbars/squashed-true.png')}')"
        page << javascript_hide("advsearchModal")
        page << javascript_hide("blocker_div")
      else
        @edit[:adv_search_open] = true
        page << "ManageIQ.explorer.clear_search_toggle(#{clear_search_status});"
        page.replace("adv_search_body", :partial => "layouts/adv_search_body")
        page.replace("adv_search_footer", :partial => "layouts/adv_search_footer")
        page << "$('#adv_search_img').prop('src', '#{ActionController::Base.helpers.image_path('toolbars/squashed-false.png')}')"
        page << ENABLE_CALENDAR if calendar_needed?
        if @edit.fetch_path(@expkey, :val1, :type)
          page << "ManageIQ.expEditor.first.type = '#{@edit[@expkey][:val1][:type]}';"
          page << "ManageIQ.expEditor.first.title = '#{@edit[@expkey][:val1][:title]}';"
        end
        if @edit.fetch_path(@expkey, :val2, :type)
          page << "ManageIQ.expEditor.second.type = '#{@edit[@expkey][:val2][:type]}';"
          page << "ManageIQ.expEditor.second.title = '#{@edit[@expkey][:val2][:title]}';"
        end
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
    exp_array(:init, @edit[@expkey][:expression])                             # Initialize the exp array
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
    @edit[@expkey][:selected] = {:id          => s.id,
                                 :name        => s.name,
                                 :description => s.description,
                                 :typ         => s.search_type}               # Save the last search loaded
    @edit[:new_search_name] = @edit[:adv_search_name] = @edit.fetch_path(@expkey, :selected, :description)
    @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
    @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Build the expression table
    exp_array(:init, @edit[@expkey][:expression])
    @edit[@expkey][:exp_token] = nil                                        # Clear the current selected token
    @edit[:adv_search_applied] = {}

    adv_search_set_text                                                 # Set search text filter suffix
    @edit[:adv_search_applied][:exp] = @edit[:new][@expkey]             # Save the expression to be applied
    @edit[@expkey].delete(:exp_token)                                   # Remove any existing atom being edited
    @edit[:adv_search_open] = false                                     # Close the adv search box
    session[:adv_search] ||= {}                                         # Create/reuse the adv search hash
    session[:adv_search][@edit[@expkey][:exp_model]] = copy_hash(@edit) # Save by model name in settings
  end

  def clear_default_search
    @edit[@expkey][:selected] = {:id => 0, :description => "All"}       # Save the last search loaded
    @edit[:adv_search_applied] = nil
    @edit[@expkey][:expression] = {"???" => "???"}                              # Set as new exp element
    @edit[:new][@expkey] = @edit[@expkey][:expression]                        # Copy to new exp
    exp_array(:init, @edit[@expkey][:expression])                             # Initialize the exp array
    @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Rebuild the expression table
    # @edit[@expkey][:exp_last_loaded] = nil                                   # Clear the last search loaded
    @edit[:adv_search_name] = nil                                             # Clear search name
    @edit[:adv_search_report] = nil                                           # Clear the report name
  end

  def load_default_search(id)
    @edit ||= {}
    @expkey = :expression                                             # Reset to use default expression key
    @edit[@expkey] ||= {}                                       # Create hash for this expression, if needed
    @edit[@expkey][:expression] = []                           # Store exps in an array
    @edit[:new] = {}
    @edit[:new][@expkey] = @edit[@expkey][:expression]                # Copy to new exp
    s = MiqSearch.find(id) unless id.zero?
    if s.nil? || s.search_key == "_hidden_" # search not found || admin changed default search to be hidden
      clear_default_search
    else
      @edit[:new][@expkey] = s.filter.exp
      @edit[@expkey][:selected] = {:id => s.id, :name => s.name, :description => s.description, :typ => s.search_type}        # Save the last search loaded
      @edit[:new_search_name] = @edit[:adv_search_name] = @edit[@expkey][:selected].nil? ? nil : @edit[@expkey][:selected][:description]
      @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Build the expression table
      exp_array(:init, @edit[@expkey][:expression])
      @edit[@expkey][:exp_token] = nil                                        # Clear the current selected token
      @edit[:adv_search_applied] = {}
      adv_search_set_text # Set search text filter suffix
      @edit[:adv_search_applied][:exp] = copy_hash(@edit[:new][@expkey])    # Save the expression to be applied
      @edit[@expkey].delete(:exp_token)                             # Remove any existing atom being edited
    end
    @edit[:adv_search_open] = false                               # Close the adv search box
  end

  # Add a new search and set the model
  def adv_search_new
    MiqSearch.new(:db => @edit[@expkey][:exp_model], :description => @edit[:new_search_name])
  end
  private :adv_search_new

  def adv_search_set_details(search, type, user=nil)
    search.update_attributes!(
      :search_key => user,
      :name => "#{type == "global" ? "global" : "user_#{user}"}_#{@edit[:new_search_name]}",
      :search_type => type
    )
  end
  private :adv_search_set_details

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
        if @edit[@expkey][:selected].nil? || # If no search was loaded
           @edit[:new_search_name] != @edit[@expkey][:selected][:description] || # or user changed the name of a loaded search
           @edit[@expkey][:selected][:typ] == "default"                          # or loaded search is a default search, save it as my search
          s = adv_search_new
          if @edit[:search_type]
            adv_search_set_details(s, "global")
          else
            adv_search_set_details(s, "user", session[:userid])
          end
        else # search was loaded exists or saving it with same name
          # Fetch the last search loaded
          s = MiqSearch.find(@edit[@expkey][:selected][:id])
          if @edit[:search_type]
            # Search selected was not global
            if s.name != "global_#{@edit[:new_search_name]}"
              s = adv_search_new
            end
              adv_search_set_details(s, "global")
          else
            # Search selected was not my search, create new search
            if s.name != "user_#{session[:userid]}_#{@edit[:new_search_name]}"
              s = adv_search_new
            end
            adv_search_set_details(s, "user", session[:userid])
          end
        end
        s.filter = MiqExpression.new(@edit[:new][@expkey]) # Set the new expression
        if s.save
          add_flash(_("%{model} search \"%{name}\" was saved") %
            {:model => ui_lookup(:model => @edit[@expkey][:exp_model]),
             :name => @edit[:new_search_name]})
          adv_search_build_lists
          # Save the last search loaded (saved)
          @edit[@expkey][:exp_last_loaded] = {:id => s.id, :name => s.name, :description => s.description, :typ => s.search_type}
          @edit[:new_search_name] = @edit[:adv_search_name] = @edit[@expkey][:exp_last_loaded][:description]
          @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
          # Build the expression table
          @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])
          exp_array(:init, @edit[@expkey][:expression])
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
        @edit[@expkey][:selected] = @edit[@expkey][:exp_last_loaded] = {:id => s.id, :name => s.name, :description => s.description, :typ => s.search_type}       # Save the last search loaded
      elsif @edit[@expkey][:exp_chosen_report]
        r = MiqReport.find(@edit[@expkey][:exp_chosen_report].to_s)
        @edit[:new][@expkey] = r.conditions.exp
        @edit[@expkey][:exp_last_loaded] = nil                                # Clear the last search loaded
        @edit[:adv_search_report] = r.name                          # Save the report name
      end
      @edit[:new_search_name] = @edit[:adv_search_name] = @edit[@expkey][:exp_last_loaded].nil? ? nil : @edit[@expkey][:exp_last_loaded][:description]
      @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Build the expression table
      exp_array(:init, @edit[@expkey][:expression])
      @edit[@expkey][:exp_token] = nil                                        # Clear the current selected token
      add_flash(_("%{model} search \"%{name}\" was successfully loaded") %
        {:model => ui_lookup(:model => @edit[@expkey][:exp_model]), :name => @edit[:new_search_name]})

    when "delete"
      s = MiqSearch.find(@edit[@expkey][:selected][:id])              # Fetch the latest record
      id = s.id
      sname = s.description
      begin
        s.destroy                                                   # Delete the record
      rescue StandardError => bang
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

      adv_search_build_lists

    when "reset"
      add_flash(_("The current search details have been reset"), :warning)

    when "apply"
      @edit[@expkey][:selected] = @edit[@expkey][:exp_last_loaded] # Save the last search loaded (saved)
      @edit[:adv_search_applied] ||= {}
      @edit[:adv_search_applied][:exp] = {}
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
      exp_get_prefill_types                                     # Get the prefill field type
    end

    # Reset fields if delete or reset ran
    if ["delete", "reset"].include?(params[:button])
      @edit[@expkey][:expression] = {"???" => "???"}              # Set as new exp element
      @edit[:new][@expkey] = @edit[@expkey][:expression]        # Copy to new exp
      exp_array(:init, @edit[@expkey][:expression])             # Initialize the exp array
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Rebuild the expression table
      @edit[@expkey][:exp_last_loaded] = nil                    # Clear the last search loaded
      @edit[:adv_search_name] = nil                             # Clear search name
      @edit[:adv_search_report] = nil                           # Clear the report name
      @edit[@expkey][:selected] = nil                           # Clear selected search
    elsif params[:button] == "save"
      @edit[:search_type] = nil
    end

    if ["delete", "saveit"].include?(params[:button])
      if @edit[:in_explorer]
        if "cs_filter_tree" == x_active_tree.to_s
          build_configuration_mananger_tree(:cs_filter, x_active_tree)
        else
          tree_type = x_active_tree.to_s.sub(/_tree/, '').to_sym
          builder = TreeBuilder.class_for_type(tree_type)
          tree = builder.new(x_active_tree, tree_type, @sb)
        end
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
          @edit[@expkey][:selected] = {:id => s.id, :name => s.name, :description => s.description, :typ => s.search_type}        # Save the last search loaded
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
    render :update do |page|
      page << javascript_prologue
      if @flash_array.blank?
        page.replace(:listnav_div, :partial => "layouts/listnav")
      else
        page.replace(:flash_msg_div, :partial => "layouts/flash_msg")
      end
      page << "miqSparkleOff();"
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
      page << "miqDynatreeActivateNodeSilently('#{x_active_tree}', '#{x_node}');" if @edit[:in_explorer]
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
    if @edit[@expkey][:exp_idx] == 0                          # Are we pointing at the first exp
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

  # Return the through_choices pulldown array for FROM datetime/date operators
  def exp_through_choices(from_choice)
    if FROM_HOURS.include?(from_choice)
      tc = FROM_HOURS
    elsif FROM_DAYS.include?(from_choice)
      tc = FROM_DAYS
    elsif FROM_WEEKS.include?(from_choice)
      tc = FROM_WEEKS
    elsif FROM_MONTHS.include?(from_choice)
      tc = FROM_MONTHS
    elsif FROM_QUARTERS.include?(from_choice)
      tc = FROM_QUARTERS
    elsif FROM_YEARS.include?(from_choice)
      tc = FROM_YEARS
    end
    # Return the THROUGH choices based on the FROM choice
    tc[0..tc.index(from_choice)]
  end

  # Get the prefill types of the fields for the current expression
  def exp_get_prefill_types
    @edit[@expkey][:val1] ||= {}
    @edit[@expkey][:val2] ||= {}
    @edit[@expkey][:val1][:type] = nil
    @edit[@expkey][:val2][:type] = nil
    if @edit[@expkey][:exp_typ] == "field"
      if @edit[@expkey][:exp_key] == EXP_IS && @edit[@expkey][:val1][:date_format] == 's'
        @edit[@expkey][:val1][:type] = :date
      else
        @edit[@expkey][:val1][:type] = exp_prefill_type(@edit[@expkey][:exp_key], @edit[@expkey][:exp_field])
      end
    elsif @edit[@expkey][:exp_typ] == "find"
      if @edit[@expkey][:exp_skey] == EXP_IS && @edit[@expkey][:val1][:date_format] == 's'
        @edit[@expkey][:val1][:type] = :date
      else
        @edit[@expkey][:val1][:type] = exp_prefill_type(@edit[@expkey][:exp_skey], @edit[@expkey][:exp_field])
      end
      if @edit[@expkey][:exp_ckey] && @edit[@expkey][:exp_ckey] == EXP_IS && @edit[@expkey][:val2][:date_format] == 's'
        @edit[@expkey][:val2][:type] = :date
      else
        @edit[@expkey][:val2][:type] = @edit[@expkey][:exp_check] == "checkcount" ? :integer : exp_prefill_type(@edit[@expkey][:exp_ckey], @edit[@expkey][:exp_cfield])
      end
    elsif @edit[@expkey][:exp_typ] == "count"
      @edit[@expkey][:val1][:type] = :integer
    elsif @edit[@expkey][:exp_typ] == "regkey"
      @edit[@expkey][:val1][:type] = :string
    end
    @edit[@expkey][:val1][:title] = MiqExpression::FORMAT_SUB_TYPES[@edit[@expkey][:val1][:type]][:title] if @edit[@expkey][:val1][:type]
    @edit[@expkey][:val2][:title] = MiqExpression::FORMAT_SUB_TYPES[@edit[@expkey][:val2][:type]][:title] if @edit[@expkey][:val2][:type]
  end

  # Get the field type for miqExpressionPrefill using the operator key and field
  def exp_prefill_type(key, field)
    return nil unless key && field
    return :regex if key.starts_with?("REG")
    typ = MiqExpression.get_col_info(field)[:format_sub_type] # :human_data_type?
    if MiqExpression::FORMAT_SUB_TYPES.keys.include?(typ)
      return typ
    else
      return :string
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

  # Set the fields for the expression editor based on the current expression
  def exp_set_fields(exp)
    exp.delete(:token)                  # Clear out the token key, if present
    key = exp.keys.first
    if exp[key]["field"]
      typ = "field"
      @edit[@expkey][:exp_field] = exp[key]["field"]
      @edit[@expkey][:exp_value] = exp[key]["value"]
      @edit[@expkey][:alias] = exp[key]["alias"]
    elsif exp[key]["count"]
      typ = "count"
      @edit[@expkey][:exp_count] = exp[key]["count"]
      @edit[@expkey][:exp_value] = exp[key]["value"]
      @edit[@expkey][:alias] = exp[key]["alias"]
    elsif exp[key]["tag"]
      typ = "tag"
      @edit[@expkey][:exp_tag] = exp[key]["tag"]
      @edit[@expkey][:exp_value] = exp[key]["value"]
      @edit[@expkey][:alias] = exp[key]["alias"]
    elsif exp[key]["regkey"]
      typ = "regkey"
      @edit[@expkey][:exp_regkey] = exp[key]["regkey"]
      @edit[@expkey][:exp_regval] = exp[key]["regval"]
      @edit[@expkey][:exp_value] = exp[key]["value"]
    elsif exp[key]["search"]
      typ = "find"
      skey = @edit[@expkey][:exp_skey] = exp[key]["search"].keys.first  # Get the search operator
      @edit[@expkey][:exp_field] = exp[key]["search"][skey]["field"]    # Get the search field
      @edit[@expkey][:alias] = exp[key]["search"][skey]["alias"]        # Get the field alias
      @edit[@expkey][:exp_available_cfields] = []                # Create the check fields pulldown array
      MiqExpression.miq_adv_search_lists(@edit[@expkey][:exp_model], :exp_available_finds).each do |af|
        if af.last.split("-").first == @edit[@expkey][:exp_field].split("-").first
          @edit[@expkey][:exp_available_cfields].push([af.first.split(":").last, af.last]) # Include fields from the chosen table
        end
      end
      @edit[@expkey][:exp_value] = exp[key]["search"][skey]["value"]    # Get the search value
      if exp[key].key?("checkall")                        # Find the check hash key
        chk = @edit[@expkey][:exp_check] = "checkall"
      elsif exp[key].key?("checkany")
        chk = @edit[@expkey][:exp_check] = "checkany"
      elsif exp[key].key?("checkcount")
        chk = @edit[@expkey][:exp_check] = "checkcount"
      end
      ckey = @edit[@expkey][:exp_ckey] = exp[key][chk].keys.first     # Get the check operator
      @edit[@expkey][:exp_cfield] = exp[key][chk][ckey]["field"]        # Get the check field
      @edit[@expkey][:exp_cvalue] = exp[key][chk][ckey]["value"]        # Get the check value
    else
      typ = nil
    end

    @edit[@expkey][:exp_key] = key.upcase
    @edit[@expkey][:exp_orig_key] = key.upcase        # Hang on to the original key for commit
    @edit[@expkey][:exp_typ] = typ

    exp_get_prefill_types                             # Get the format sub types of the fields in this atom

    @edit[:suffix] = @edit[:suffix2] = nil
    unless @edit[@expkey][:exp_value] == :user_input  # Ignore user input fields
      if @edit.fetch_path(@expkey, :val1, :type) == :bytes
        if is_numeric?(@edit[@expkey][:exp_value])                        # Value is a number
          @edit[:suffix] = :bytes                                         #  Default to :bytes
          @edit[@expkey][:exp_value] = @edit[@expkey][:exp_value].to_s    #  Get the value
        else                                                              # Value is a string
          @edit[:suffix] = @edit[@expkey][:exp_value].split(".").last.to_sym  #  Get the suffix
          @edit[@expkey][:exp_value] = @edit[@expkey][:exp_value].split(".")[0...-1].join(".")  # Remove the suffix
        end
      end
    end
    if @edit.fetch_path(@expkey, :val2, :type) == :bytes
      if is_numeric?(@edit[@expkey][:exp_cvalue])                       # Value is a number
        @edit[:suffix2] = :bytes                                        #  Default to :bytes
        @edit[@expkey][:exp_cvalue] = @edit[@expkey][:exp_cvalue].to_s  #  Get the value
      else                                                              # Value is a string
        @edit[:suffix2] = @edit[@expkey][:exp_cvalue].split(".").last.to_sym  #  Get the suffix
        @edit[@expkey][:exp_cvalue] = @edit[@expkey][:exp_cvalue].split(".")[0...-1].join(".")  # Remove the suffix
      end
    end

    # Change datetime and date field values into arrays while editing
    if [:datetime, :date].include?(@edit.fetch_path(@expkey, :val1, :type))
      @edit[@expkey][:exp_value] = @edit[@expkey][:exp_value].to_miq_a  # Turn date/time values into an array
      @edit[@expkey][:val1][:date_format] = @edit[@expkey][:exp_value].to_s.first.include?("/") ? "s" : "r"
      if key == EXP_FROM && @edit[@expkey][:val1][:date_format] == "r"
        @edit[@expkey][:val1][:through_choices] = exp_through_choices(@edit[@expkey][:exp_value][0])
      end
    end
    if [:datetime, :date].include?(@edit.fetch_path(@expkey, :val2, :type))
      @edit[@expkey][:exp_cvalue] = @edit[@expkey][:exp_cvalue].to_miq_a  # Turn date/time cvalues into an array
      @edit[@expkey][:val2][:date_format] = @edit[@expkey][:exp_cvalue].first.include?("/") ? "s" : "r"
      if ckey == EXP_FROM && @edit[@expkey][:val2][:date_format] == "r"
        @edit[@expkey][:val2][:through_choices] = exp_through_choices(@edit[@expkey][:exp_cvalue][0])
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
                                           (@edit[@expkey][:exp_value].to_s + (@edit[:suffix] ? ".#{@edit[:suffix]}" : ""))
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
            exp[@edit[@expkey][:exp_key]]["value"] += ".#{@edit[:suffix]}" if @edit[:suffix] # Append the suffix, if present
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
                                           (@edit[@expkey][:exp_value].to_s + (@edit[:suffix] ? ".#{@edit[:suffix]}" : ""))
                                        )
        add_flash(_("Find Value Error: %{msg}") % {:msg => e}, :error)
      elsif e = MiqExpression.atom_error(@edit[@expkey][:exp_check] == "checkcount" ? :count : @edit[@expkey][:exp_cfield],
                                         @edit[@expkey][:exp_ckey],
                                         @edit[@expkey][:exp_cvalue].kind_of?(Array) ?
                                           @edit[@expkey][:exp_cvalue] :
                                           (@edit[@expkey][:exp_cvalue].to_s + (@edit[:suffix2] ? ".#{@edit[:suffix2]}" : ""))
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
          exp[@edit[@expkey][:exp_key]]["search"][skey]["value"] += ".#{@edit[:suffix]}" if @edit[:suffix] # Append the suffix, if present
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
          exp[@edit[@expkey][:exp_key]][chk][ckey]["value"] += ".#{@edit[:suffix2]}" if @edit[:suffix2]  # Append the suffix, if present
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

  # Method to maintain the expression undo array in @edit[@expkey][:exp_array]
  def exp_array(func, exp = nil)
    @edit[@expkey][:exp_array] ||= []
    exp_ary = @edit[@expkey][:exp_array]          # Put exp array in local var
    exp_idx = @edit[@expkey][:exp_idx]            # Put exp index in local var
    case func
    when :init
      exp_ary = @edit[@expkey][:exp_array] = []      # Clear/create the exp array
      exp_idx = 0                                 # Initialize the exp index
      exp_ary.push(copy_hash(exp))                # Push the exp onto the array
    when :push
      exp_idx = exp_ary.blank? ? 0 : exp_idx + 1      # Increment index to next array element
      exp_ary.slice!(exp_idx..-1) if exp_ary[exp_idx] # Remove exp_idx element and above
      exp_ary.push(copy_hash(exp))                    # Push the new exp onto the array
    when :undo
      if exp_idx > 0                              # If not on first element
        @edit[@expkey][:exp_idx] -= 1                     # Decrement exp index
        return copy_hash(exp_ary[exp_idx - 1])    # Return the prior exp
      end
    when :redo
      if exp_idx < exp_ary.length - 1             # If not on last element
        @edit[@expkey][:exp_idx] += 1                     # Increment exp index
        return copy_hash(exp_ary[exp_idx + 1])    # Return the next exp
      end
    end
    @edit[@expkey][:exp_idx] = exp_idx                      # Save local index back to @edit object
    nil                                    # Return nil if no exp was returned
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
      @edit[@expkey] ||= {}                                       # Create hash for this expression, if needed
      @edit[@expkey][:expression] = []                           # Store exps in an array
      @edit[@expkey][:exp_idx] = 0                                      # Start at first exp
      @edit[@expkey][:expression] = {"???" => "???"}                      # Set as new exp element
      @edit[@expkey][:use_mytags] = true                                # Include mytags in tag search atoms
      @edit[:custom_search] = false                                     # setting default to false
      @edit[:new] = {}
      @edit[:new][@expkey] = @edit[@expkey][:expression]                # Copy to new exp
      exp_array(:init, @edit[@expkey][:expression])                     # Initialize the exp array
      @edit[:adv_search_open] = false
      @edit[@expkey][:exp_model] = model.to_s
      @edit[:flash_div_num] = "2"
    end
    @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Build the table to display the exp
    @edit[:in_explorer] = @explorer # Remember if we're in an explorer

    if @hist && @hist[:qs_exp] # Override qs exp if qs history button was pressed
      @edit[:adv_search_applied] = {:text => @hist[:text], :qs_exp => @hist[:qs_exp]}
      session[:adv_search][model.to_s] = copy_hash(@edit) # Save updated adv_search options
    end
  end

  # Build the pulldown lists for the adv search box
  def adv_search_build_lists
    db = @edit[@expkey][:exp_model]
    global_expressions = MiqSearch.get_expressions(
      :db          => db,
      :search_type => "global"
    )
    user_expressions = MiqSearch.get_expressions(
      :db          => db,
      :search_type => "user",
      :search_key  => session[:userid]
    )

    user_expressions = Array(user_expressions).sort
    global_expressions = Array(global_expressions).sort
    global_expressions.each { |ge| ge[0] = "Global - #{ge[0]}" }
    @edit[@expkey][:exp_search_expressions] = global_expressions + user_expressions
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

  def process_changed_expression(params, chosen_key, exp_key, exp_value, exp_valx)
    # Remove the second exp_value if the operator changed from EXP_FROM
    @edit[@expkey][exp_value].delete_at(1) if @edit[@expkey][exp_key] == EXP_FROM

    # Set THROUGH value if changing to FROM
    if params[chosen_key] == EXP_FROM
      if @edit[@expkey][exp_valx][:date_format] == "r" # Format is relative
        @edit[@expkey][exp_valx][:through_choices] = exp_through_choices(@edit[@expkey][exp_value][0])
        @edit[@expkey][exp_value][1] = @edit[@expkey][exp_valx][:through_choices].first
      else                                          # Format is specific, just add second value
        @edit[@expkey][exp_value][1] = nil
      end
    end

    @edit[@expkey][exp_key] = params[chosen_key]  # Save the key
    exp_get_prefill_types # Prefill type may change based on selected key for date/time fields

    # Convert to/from "<date>" and "<date time>" strings in the exp_value array for specific date/times
    if @edit[@expkey][exp_valx][:date_format] == "s"
      if [:datetime, :date].include?(@edit[@expkey][exp_valx][:type])
        @edit[@expkey][exp_value].each_with_index do |v, v_idx|
          next if v.blank?
          if params[chosen_key] == EXP_IS || @edit[@expkey][exp_valx][:type] == :date
            @edit[@expkey][exp_value][v_idx] = v.split(" ").first if v.include?(":")
          else
            @edit[@expkey][exp_value][v_idx] = v + " 00:00" unless v.include?(":")
          end
        end
      end
    end
  end

  def process_datetime_expression_field(value_key, exp_key, exp_value_key)
    if [:date, :datetime].include?(@edit[@expkey][value_key][:type])  # Set value for date/time fields
      @edit[@expkey][value_key][:date_format] ||= "r"
      if @edit[@expkey][exp_key] == EXP_FROM
        @edit[@expkey][exp_value_key] = @edit[@expkey][value_key][:date_format] == "s" ?
                                      Array.new(2) :
                                      [EXP_TODAY, EXP_TODAY]
        @edit[@expkey][value_key][:through_choices] = [EXP_TODAY] if @edit[@expkey][value_key][:date_format] == "r"
      else
        @edit[@expkey][exp_value_key] = @edit[@expkey][value_key][:date_format] == "s" ? [] : [EXP_TODAY]
      end
    end
  end

  def process_datetime_selector(param_key_suffix, exp_key = nil)
    param_date_key  = "miq_date_#{param_key_suffix}".to_sym
    param_time_key  = "miq_time_#{param_key_suffix}".to_sym
    return unless params[param_date_key] || params[param_time_key]

    exp_value_index = param_key_suffix[-1].to_i
    value_key       = "val#{param_key_suffix[0]}".to_sym
    exp_value_key   = param_key_suffix.starts_with?("1") ? :exp_value : :exp_cvalue
    exp             = @edit[@expkey]

    date = params[param_date_key] || (params[param_time_key] && exp[exp_value_key][exp_value_index].split(' ').first)
    time = params[param_time_key] if params[param_time_key]

    if time.to_s.blank? && exp[value_key][:type] == :datetime && exp[exp_key] != EXP_IS
      time = "00:00" # If time is blank, add in midnight if needed
    end

    time = " #{time}" unless time.to_s.blank? # Prepend a blank, if time is non-blank

    exp[exp_value_key][exp_value_index] = "#{date}#{time}"
  end

  ENABLE_CALENDAR = "miqBuildCalendar();".freeze
  def calendar_needed?
    return true if [:date, :datetime].include?(@edit.fetch_path(@expkey, :val1, :type))
    return true if [:date, :datetime].include?(@edit.fetch_path(@expkey, :val2, :type))
    false
  end
end
