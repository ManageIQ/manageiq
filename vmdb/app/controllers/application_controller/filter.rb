# Filter/search/expression methods included in application.rb
module ApplicationController::Filter
  extend ActiveSupport::Concern

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
      add_flash(I18n.t("flash.button.not_implemented"), :error)
    end

    if flash_errors?
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_div#{div_num}", :partial=>"layouts/flash_msg", :locals=>{:div_num=>div_num})
      end
    else
      if ["commit", "not", "remove"].include?(params[:pressed])
        @edit[:new][@expkey] = copy_hash(@edit[@expkey][:expression], :token)
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
          page.replace_html("adv_search_div", :partial=>"layouts/adv_search")
        else
          page.replace("exp_editor_div", :partial=>"layouts/exp_editor")
        end
        if ["not","discard","commit","remove"].include?(params[:pressed])
          page << "$('exp_buttons_on').hide();"
          page << "$('exp_buttons_not').hide();"
          page << "$('exp_buttons_off').show();"
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
        @exp_atom_errors = [I18n.t("flash.edit.exp_atom_error_1"),
                            I18n.t("flash.edit.exp_atom_error_2"),
                            I18n.t("flash.edit.error_details", :error=>bang)]
      end
      @edit[@expkey][:exp_token] = token
      render :update do |page|
        page.replace("flash_msg_div#{div_num}", :partial=>"layouts/flash_msg", :locals=>{:div_num=>div_num})
        page.replace("exp_editor_div", :partial=>"layouts/exp_editor")
        page << "$('exp_#{token}').setStyle('background-color: yellow')"
        page << "$('exp_buttons_off').hide();"
        if exp.has_key?("not") or @parent_is_not
          page << "$('exp_buttons_on').hide();"
          page << "$('exp_buttons_not').show();"
        else
          page << "$('exp_buttons_not').hide();"
          page << "$('exp_buttons_on').show();"
        end

        if [:date, :datetime].include?(@edit.fetch_path(@expkey, :val1, :type)) ||
            [:date, :datetime].include?(@edit.fetch_path(@expkey, :val2, :type))
          page << "miqBuildCalendar();"
        end

        if @edit[@expkey][:exp_key] && @edit[@expkey][:exp_field]
          page << "miq_val1_type = '#{@edit[@expkey][:val1][:type].to_s}';" if @edit[@expkey][:val1][:type]
          page << "miq_val1_title = '#{@edit[@expkey][:val1][:title]}';" if @edit[@expkey][:val1][:type]
          page << "miq_val2_type = '#{@edit[@expkey][:val2][:type].to_s}';" if @edit[@expkey][:val2][:type]
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
          if @edit[@expkey][:exp_cfield] != nil &&  # Clear expression check portion
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
      if params[:miq_date_1_0]                                # First date selector
        if @edit[@expkey][:exp_value][0].to_s.include?(":")   # Already has a time, just swap in the date
          @edit[@expkey][:exp_value][0] = params[:miq_date_1_0] + " " + @edit[@expkey][:exp_value][0].split(" ").last
        else                                                  # No time already, add in midnight if needed
          @edit[@expkey][:exp_value][0] = params[:miq_date_1_0] +
            ((@edit[@expkey][:val1][:type] == :datetime && @edit[@expkey][:exp_key] != EXP_IS) ? " 00:00" : "")
        end
      end
      if params[:miq_date_1_1]                                # 2nd date selector, only on FROM
        if @edit[@expkey][:exp_value][1].to_s.include?(":")   # Already has a time, just swap in the date
          @edit[@expkey][:exp_value][1] = params[:miq_date_1_1] + " " + @edit[@expkey][:exp_value][1].split(" ").last
        else                                                  # No time already, add in midnight if needed
          @edit[@expkey][:exp_value][1] = params[:miq_date_1_1] +
            (@edit[@expkey][:val1][:type] == :datetime ? " 00:00" : "")
        end
      end
      if params[:miq_date_2_0]                                # First date selector in FIND/CHECK
        if @edit[@expkey][:exp_cvalue][0].to_s.include?(":")  # Already has a time, just swap in the date
          @edit[@expkey][:exp_cvalue][0] = params[:miq_date_2_0] + " " + @edit[@expkey][:exp_cvalue][0].split(" ").last
        else                                                  # No time already, add in midnight if needed
          @edit[@expkey][:exp_cvalue][0] = params[:miq_date_2_0] +
            ((@edit[@expkey][:val2][:type] == :datetime && @edit[@expkey][:exp_ckey] != EXP_IS) ? " 00:00" : "")
        end
      end
      if params[:miq_date_2_1]                                # 2nd date selector, only on FROM
        if @edit[@expkey][:exp_cvalue][1].to_s.include?(":")  # Already has a time, just swap in the date
          @edit[@expkey][:exp_cvalue][1] = params[:miq_date_2_1] + " " + @edit[@expkey][:exp_cvalue][1].split(" ").last
        else                                                  # No time already, add in midnight if needed
          @edit[@expkey][:exp_cvalue][1] = params[:miq_date_2_1] +
            (@edit[@expkey][:val2][:type] == :datetime ? " 00:00" : "")
        end
      end
      if params[:miq_time_1_0]
        @edit[@expkey][:exp_value][0] = @edit[@expkey][:exp_value][0].split(" ").first + " " + params[:miq_time_1_0]
      end
      if params[:miq_time_1_1]
        @edit[@expkey][:exp_value][1] = @edit[@expkey][:exp_value][1].split(" ").first + " " + params[:miq_time_1_1]
      end
      if params[:miq_time_2_0]
        @edit[@expkey][:exp_cvalue][0] = @edit[@expkey][:exp_cvalue][0].split(" ").first + " " + params[:miq_time_2_0]
      end
      if params[:miq_time_2_1]
        @edit[@expkey][:exp_cvalue][1] = @edit[@expkey][:exp_cvalue][1].split(" ").first + " " + params[:miq_time_2_1]
      end

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
    if params[:date_format_1]
      @edit[@expkey][:val1][:date_format] = params[:date_format_1]
      @edit[@expkey][:exp_value].collect!{|v| v = params[:date_format_1] == "s" ? nil : EXP_TODAY}
      @edit[@expkey][:val1][:through_choices] = exp_through_choices(@edit[@expkey][:exp_value][0]) if params[:date_format_1] == "r"
    end
    if params[:date_format_2]
      @edit[@expkey][:val2][:date_format] = params[:date_format_2]
      @edit[@expkey][:exp_cvalue].collect!{|v| v = params[:date_format_2] == "s" ? nil : EXP_TODAY}
      @edit[@expkey][:val2][:through_choices] = exp_through_choices(@edit[@expkey][:exp_cvalue][0]) if params[:date_format_2] == "r"
    end

    # Check for suffixes changed
    @edit[:suffix] = params[:chosen_suffix].to_sym if params[:chosen_suffix]
    @edit[:suffix2] = params[:chosen_suffix2].to_sym if params[:chosen_suffix2]

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
          page.replace("exp_atom_editor_div", :partial=>"layouts/exp_atom/editor")

          if [:date, :datetime].include?(@edit.fetch_path(@expkey, :val1, :type)) ||
              [:date, :datetime].include?(@edit.fetch_path(@expkey, :val2, :type))
            page << "miqBuildCalendar();"
          end

          page << "miq_val1_type = '#{@edit[@expkey][:val1][:type].to_s}';" if @edit.fetch_path(@expkey,:val1,:type)
          page << "miq_val1_title = '#{@edit[@expkey][:val1][:title]}';" if @edit.fetch_path(@expkey,:val1,:type)
          page << "miq_val2_type = '#{@edit[@expkey][:val2][:type].to_s}';" if @edit.fetch_path(@expkey,:val2,:type)
          page << "miq_val2_title = '#{@edit[@expkey][:val2][:title]}';" if @edit.fetch_path(@expkey,:val2,:type)

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
      if @edit[:adv_search_open] == true
        @edit[:adv_search_open] = false
        page << "$('adv_search_img').src='/images/toolbars/squashed-true.png'"
        page << "$('adv_search_div').hide();"
        page << "$('blocker_div').hide();"
#       page << "$('adv_search_div').visualEffect('blind_up', {duration:1.5});"
      else
        @edit[:adv_search_open] = true
        page.replace_html("adv_search_div", :partial=>"layouts/adv_search")
        page << "$('adv_search_img').src='/images/toolbars/squashed-false.png'"
        page << "$('adv_search_div').show();"
        page << "$('blocker_div').show();"
#       page << "$('adv_search_div').visualEffect('blind_down', {duration:1.5});"

        if [:date, :datetime].include?(@edit.fetch_path(@expkey, :val1, :type)) ||
            [:date, :datetime].include?(@edit.fetch_path(@expkey, :val2, :type))
          page << "miqBuildCalendar();"
        end

        page << "miq_val1_type = '#{@edit[@expkey][:val1][:type].to_s}';" if @edit.fetch_path(@expkey,:val1,:type)
        page << "miq_val1_title = '#{@edit[@expkey][:val1][:title]}';" if @edit.fetch_path(@expkey,:val1,:type)
        page << "miq_val2_type = '#{@edit[@expkey][:val2][:type].to_s}';" if @edit.fetch_path(@expkey,:val2,:type)
        page << "miq_val2_title = '#{@edit[@expkey][:val2][:title]}';" if @edit.fetch_path(@expkey,:val2,:type)
      end
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
      @edit[:adv_search_applied] = nil
      @edit[@expkey][:expression] = {"???"=>"???"}                              # Set as new exp element
      @edit[:new][@expkey] = copy_hash(@edit[@expkey][:expression])             # Copy to new exp
      exp_array(:init, @edit[@expkey][:expression])                             # Initialize the exp array
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Rebuild the expression table
      #@edit[@expkey][:exp_last_loaded] = nil                                   # Clear the last search loaded
      #@edit[@expkey][:exp_last_loaded] = {:id=>0}                                # Save the last search loaded
      @edit[@expkey][:selected] = {:id=>0}                                      # Save the last search loaded
      @edit[:adv_search_name] = nil                                             # Clear search name
      @edit[:adv_search_report] = nil                                           # Clear the report name
    else
      @expkey = :expression     # Reset to use default expression key
      @edit[:new] = Hash.new
      s = MiqSearch.find(id.to_s)
      @edit[:new][@expkey] = s.filter.exp
      if s.filter.quick_search?
        @quick_search_active = true
        @edit[:qs_prev_x_node] = x_node if @edit[:in_explorer] # Remember current tree node
        @edit[@expkey][:pre_qs_selected] = @edit[@expkey][:selected]            # Save previous selected search
        @edit[:qs_prev_adv_search_applied] = @edit[:adv_search_applied]         # Save any existing adv search
      end
      @edit[@expkey][:selected] = {:id=>s.id, :name=>s.name, :description=>s.description, :typ=>s.search_type}        # Save the last search loaded
      @edit[:new_search_name] = @edit[:adv_search_name] = @edit[@expkey][:selected] == nil ? nil : @edit[@expkey][:selected][:description]
      @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
      @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Build the expression table
      exp_array(:init, @edit[@expkey][:expression])
      @edit[@expkey][:exp_token] = nil                                        # Clear the current selected token
      @edit[:adv_search_applied] = Hash.new
#      if s.filter.quick_search?
#        @edit[:qs_prev_x_node] = x_node # Remember current tree node
#      end
      adv_search_set_text # Set search text filter suffix
      @edit[:adv_search_applied][:exp] = @edit[:new][@expkey]   # Save the expression to be applied
      @edit[@expkey].delete(:exp_token)                         # Remove any existing atom being edited
      @edit[:adv_search_open] = false                           # Close the adv search box
    end
    session[:adv_search] ||= Hash.new                         # Create/reuse the adv search hash
    session[:adv_search][@edit[@expkey][:exp_model]] = copy_hash(@edit) # Save by model name in settings
    unless @explorer
      respond_to do |format|
        format.js do
          if @quick_search_active
            quick_search_show
          else
            render :update do |page|
              page.redirect_to :action => 'show_list' # Redirect to build the list screen
            end
          end
        end
        format.html do
          redirect_to :action => 'show_list'  # Redirect to build the list screen
        end
      end
    end
  end

  def clear_default_search
    @edit[@expkey][:selected] = {:id=>0, :description=>"All"}       # Save the last search loaded
    @edit[:adv_search_applied] = nil
    @edit[@expkey][:expression] = {"???"=>"???"}                              # Set as new exp element
    @edit[:new][@expkey] = @edit[@expkey][:expression]                        # Copy to new exp
    exp_array(:init, @edit[@expkey][:expression])                             # Initialize the exp array
    @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Rebuild the expression table
    #@edit[@expkey][:exp_last_loaded] = nil                                   # Clear the last search loaded
    @edit[:adv_search_name] = nil                                             # Clear search name
    @edit[:adv_search_report] = nil                                           # Clear the report name
  end

  def load_default_search(id)
    @edit ||= Hash.new
    @expkey = :expression                                             # Reset to use default expression key
    @edit[@expkey] ||= Hash.new                                       # Create hash for this expression, if needed
    @edit[@expkey][:expression] = Array.new                           # Store exps in an array
    @edit[:new] = Hash.new
    @edit[:new][@expkey] = @edit[@expkey][:expression]                # Copy to new exp
    if id == 0 || !MiqSearch.exists?(id)
      clear_default_search
    else
      s = MiqSearch.find(id)
      if s.search_key == "_hidden_"           #if admin has changed default search to be hidden
        clear_default_search
      else
        @edit[:new][@expkey] = s.filter.exp
        @edit[@expkey][:selected] = {:id=>s.id, :name=>s.name, :description=>s.description, :typ=>s.search_type}        # Save the last search loaded
        @edit[:new_search_name] = @edit[:adv_search_name] = @edit[@expkey][:selected] == nil ? nil : @edit[@expkey][:selected][:description]
        @edit[@expkey][:expression] = copy_hash(@edit[:new][@expkey])
        @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression])       # Build the expression table
        exp_array(:init, @edit[@expkey][:expression])
        @edit[@expkey][:exp_token] = nil                                        # Clear the current selected token
        @edit[:adv_search_applied] = Hash.new
        adv_search_set_text # Set search text filter suffix
        @edit[:adv_search_applied][:exp] = copy_hash(@edit[:new][@expkey])    # Save the expression to be applied
        @edit[@expkey].delete(:exp_token)                             # Remove any existing atom being edited
      end
    end
    @edit[:adv_search_open] = false                               # Close the adv search box
  end

  # One of the form buttons was pressed on the advanced search panel
  def adv_search_button
    @edit = session[:edit]
    @view = session[:view]
    @edit[:custom_search] = false             # setting default to false
    case params[:button]
    when "saveit"
      if @edit[:new_search_name] == nil || @edit[:new_search_name] == ""
        add_flash(I18n.t("flash.edit.field_required", :field=>"Search Name"), :error)
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
          add_flash(I18n.t("flash.edit.saved",
                          :model=>"#{ui_lookup(:model=>@edit[@expkey][:exp_model])} search",
                          :name=>@edit[:new_search_name]))
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
      add_flash(I18n.t("flash.record.was_loaded",
                      :model=>"#{ui_lookup(:model=>@edit[@expkey][:exp_model])} search",
                      :name=>@edit[:new_search_name]))

    when "delete"
      s = MiqSearch.find(@edit[@expkey][:selected][:id])              # Fetch the latest record
      id = s.id
      sname = s.description
      begin
        s.destroy                                                   # Delete the record
      rescue StandardError => bang
        add_flash(I18n.t("flash.record.error_during",
                        :model=>ui_lookup(:model=>"MiqSearch"), :name=>sname, :task=>"delete") << bang.message,
                  :error)
      else
        if @settings[:default_search] && @settings[:default_search][@edit[@expkey][:exp_model].to_s.to_sym] # See if a default search exists
          def_search = @settings[:default_search][@edit[@expkey][:exp_model].to_s.to_sym]
          if id.to_i == def_search.to_i
            db_user = User.find_by_userid(session[:userid])
            db_user.settings[:default_search].delete(@edit[@expkey][:exp_model].to_s.to_sym)
            db_user.save
            @edit[:adv_search_applied] = nil          # clearing up applied search results
          end
        end
        add_flash(I18n.t("flash.record.deleted",
                        :model=>"#{ui_lookup(:model=>@edit[@expkey][:exp_model])} search",
                        :name=>sname))
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
      add_flash(I18n.t("flash.edit.filter.current_search_reset"), :warning)

    when "apply"
      @edit[@expkey][:selected] = @edit[@expkey][:exp_last_loaded] # Save the last search loaded (saved)
      @edit[:adv_search_applied] ||= Hash.new
      @edit[:adv_search_applied][:exp] = Hash.new
      adv_search_set_text # Set search text filter suffix
      @edit[:selected] = true
      @edit[:adv_search_applied][:exp] = @edit[:new][@expkey]   # Save the expression to be applied
      @edit[@expkey].delete(:exp_token)                         # Remove any existing atom being edited
#     @edit[:adv_search_open] = false                           # Close the adv search box
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
          page.redirect_to :action => 'show_list'                 # redirect to build the list screen
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
        build_vm_tree(:filter, x_active_tree) # Rebuild active VM filter tree
      else
        build_listnav_search_list(@edit[@expkey][:exp_model])
      end
    end

    render :update do |page|
      if ["load","save"].include?(params[:button])
        page.replace_html("adv_search_div", :partial=>"layouts/adv_search", :locals=>{:mode=>params[:button]})
      else
        @edit[@expkey][:exp_chosen_report] = nil
        @edit[@expkey][:exp_chosen_search] = nil
        page.replace_html("adv_search_div", :partial=>"layouts/adv_search")
      end

      if ["delete","saveit"].include?(params[:button])
        if @edit[:in_explorer]
          tree = x_active_tree.to_s
          page.replace_html("#{tree}_div", :partial=>"vm_common/#{tree}")
        else
          page.replace(:listnav_div, :partial=>"layouts/listnav")
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
      page.replace_html("adv_search_div", :partial=>"layouts/adv_search", :locals=>{:mode=>'load'})
    end
  end

  # Character typed into search name field
  def adv_search_name_typed
    @edit = session[:edit]
    @edit[:new_search_name] = params[:search_name] if params[:search_name]
    @edit[:search_type] = params[:search_type].to_s == "1" ? "global" : nil if params[:search_type]
    render :update do |page|
    end
  end

  # Clear the applied search
  def adv_search_clear
    respond_to do |format|
      format.js do
        @explorer = true
        if x_tree[:type] == :filter &&
            !["Vm", "MiqTemplate"].include?(X_TREE_NODE_PREFIXES[@nodetype])
          search_id = 0
          adv_search_build(vm_model_from_active_tree(x_active_tree))
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

  # Save default search
  def save_default_search
    @edit = session[:edit]
    @view = session[:view]
    cols_key = @view.scoped_association.nil? ? @view.db.to_sym : (@view.db + "-" + @view.scoped_association).to_sym
    if params[:id]
      if params[:id] != "0"
        s = MiqSearch.find_by_id(params[:id])
        if s.nil?
          add_flash(I18n.t("flash.search_not_found"), :error)
        elsif MiqExpression.quick_search?(s.filter)
          add_flash(I18n.t("flash.search_requires_input"), :error)
        end
      end
      if @flash_array.blank?
        db_user = User.find_by_userid(session[:userid])
        if db_user != nil
          db_user.settings[:default_search] ||= Hash.new                        # Create the col widths hash, if not there
          db_user.settings[:default_search][cols_key] ||= Hash.new        # Create hash for the view db
          @settings[:default_search] ||= Hash.new                               # Create the col widths hash, if not there
          @settings[:default_search][cols_key] ||= Hash.new             # Create hash for the view db
          @settings[:default_search][cols_key] = params[:id].to_i # Save each cols width
          db_user.settings[:default_search][cols_key] = @settings[:default_search][cols_key]
          db_user.save
        end
      end
    end
    build_listnav_search_list(@view.db) if @flash_array.blank?
    render :update do |page|
      if @flash_array.blank?
        page.replace(:listnav_div, :partial=>"layouts/listnav")
      else
        page.replace(:flash_msg_div, :partial=>"layouts/flash_msg")
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
      render(:update) { |page| page.redirect_to(:action => 'show_list') }
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

    js_options = {:hide_show_elements => {}}
    js_options[:hide_show_elements][:quicksearchbox] = false
    if @edit[:adv_search_open]
      js_options[:hide_show_elements][:advsearchbox] = true
    else
      js_options[:hide_show_elements][:blocker_div] = false
    end
    js_options[:sf_node] = x_node if @edit[:in_explorer] # select a focus
    js_options[:miq_button_visibility] = false
    # Render the JS responses to update the quick_search
    render :partial => "shared/quick_search", :locals => {:options => js_options}
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
        page << javascript_for_miq_button_visibility(!any_empty)
      end
    end
  end

  private

  # Go thru an expression and replace the quick search tokens
  def exp_replace_qs_tokens(exp, tokens)
    key = exp.keys.first
    if ["and", "or"].include?(key)
      exp[key].each{|e| exp_replace_qs_tokens(e, tokens)}
    elsif key == "not"
      exp_replace_qs_tokens(exp[key], tokens)
    elsif exp.has_key?(:token) && exp[key].has_key?("value")
      token = exp[:token]
      if tokens[token]                # Only atoms included in tokens will have user input
        value = tokens[token][:value] # Get the user typed value
        if tokens[token][:value_type] == :bytes
          value += ".#{tokens[token][:suffix] || "bytes"}"  # For :bytes type, add in the suffix
        end
        exp[key]["value"] = value     # Replace the exp value with the proper qs value
      end
    end
  end

  # Popup/open the quick search box
  def quick_search_show
    @exp_token           = nil
    @quick_search_active = true
    @qs_exp_table        = exp_build_table(@edit[:adv_search_applied][:exp], true)

    # Create a hash to store quick search information by token
    # and add in other quick search exp atom information.
    @edit[:qs_tokens] = @qs_exp_table.select { |e| e.is_a?(Array) }.each_with_object({}) do |e, acc|
      token      = e.last
      acc[token] = {:value => nil}
      exp        = exp_find_by_token(@edit[:adv_search_applied][:exp], token)
      first_exp  = exp[exp.keys.first]

      if first_exp.key?("field")  # Base token settings on exp type
        field = exp[exp.keys.first]["field"]
        acc[token][:field]      = field
        acc[token][:value_type] = MiqExpression.get_col_info(field)[:format_sub_type]
      elsif first_exp.key?("tag")
        acc[token][:tag]   = first_exp["tag"]
      elsif first_exp.key?("count")
        acc[token][:count] = first_exp["count"]
      end
    end

    render :update do |page|
      page.replace(:quicksearchbox, :partial => "layouts/quick_search")
      page << "if ($('advsearchbox')) $('advsearchbox').hide();"
      page << "$('blocker_div').show();"
      page << "$('quicksearchbox').show();"
      page << "miqSparkle(false);"
    end
  end

  # Set advanced search filter text
  def adv_search_set_text
    if @edit[@expkey][:exp_idx] == 0                          # Are we pointing at the first exp
      if @edit[:adv_search_name]
        @edit[:adv_search_applied][:text] = " - Filtered by \"#{@edit[:adv_search_name]}\""
      else
        @edit[:adv_search_applied][:text] = " - Filtered by \"#{@edit[:adv_search_report]}\" report"
      end
    else
      @edit[:custom_search] = true
      @edit[:adv_search_applied][:text] = " - Filtered by custom search"
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
        return tc[0..tc.index(from_choice)]
  end

  # Get the prefill types of the fields for the current expression
  def exp_get_prefill_types
    @edit[@expkey][:val1] ||= Hash.new
    @edit[@expkey][:val2] ||= Hash.new
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
      @edit[@expkey][:val1][:type] = @edit[@expkey][:exp_key] == "RUBY" ? :ruby : :string
    end
    @edit[@expkey][:val1][:title] = FORMAT_SUB_TYPES[@edit[@expkey][:val1][:type]][:title] if @edit[@expkey][:val1][:type]
    @edit[@expkey][:val2][:title] = FORMAT_SUB_TYPES[@edit[@expkey][:val2][:type]][:title] if @edit[@expkey][:val2][:type]
  end

  # Get the field type for miqExpressionPrefill using the operator key and field
  def exp_prefill_type(key, field)
    return nil unless key && field
    if key.include?("RUBY")
      return :ruby
    elsif key.starts_with?("REG")
      return :regex
    end
    typ = MiqExpression.get_col_info(field)[:format_sub_type] # :human_data_type?
    if FORMAT_SUB_TYPES.keys.include?(typ)
      return typ
    else
      return :string
    end
  end

  # Build an array of expression symbols by recursively traversing the MiqExpression object
  #   and inserting sequential tokens for each expression part
  def exp_build_table(exp, quick_search = false)
    exp_table = Array.new
    if exp["and"]
      exp_table.push("(")
      exp["and"].each do |e|
        exp_table += exp_build_table(e, quick_search)
        exp_table.push("AND") unless e == exp["and"].last
      end
      exp_table.push(")")
    elsif exp["or"]
      exp_table.push("(")
      exp["or"].each do |e|
        exp_table += exp_build_table(e, quick_search)
        exp_table.push("OR") unless e == exp["or"].last
      end
      exp_table.push(")")
    elsif exp["not"]
      @exp_token ||= 0
      @exp_token = @exp_token + 1
      exp[:token] = @exp_token
      exp_table.push(quick_search ? "NOT" : ["NOT", @exp_token])  # No token if building quick search exp
      exp_table.push("(") if !["and","or"].include?(exp["not"].keys.first)  # No parens if and/or under me
      exp_table += exp_build_table(exp["not"], quick_search)
      exp_table.push(")") if !["and","or"].include?(exp["not"].keys.first)  # No parens if and/or under me
    else
      @exp_token ||= 0
      @exp_token = @exp_token + 1
      exp[:token] = @exp_token
      if exp["???"]                             # Found a new expression part
        exp_table.push(["???", @exp_token])
        @edit[@expkey][:exp_token] = @exp_token         # Save the token value for the view
        @edit[:edit_exp] = copy_hash(exp)       # Save the exp part for the view
        exp_set_fields(@edit[:edit_exp])        # Set the fields for a new exp part
      else
        if quick_search # Separate out the user input fields if doing a quick search
          human_exp = MiqExpression.to_human(exp)
          if human_exp.include?("<user input>")
            exp_table.push(human_exp.split("<user input>").join(""))
            exp_table.push([:user_input, @exp_token])
          else
            exp_table.push(human_exp)
          end
        else            # Not quick search, add token to the expression
          exp_table.push([MiqExpression.to_human(exp), @exp_token])
        end
      end
    end
    return exp_table
  end

  # Remove :token keys from an expression before setting in a record
  def exp_remove_tokens(exp)
    if exp.is_a?(Array)         # Is this and AND or OR
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

  # Find an expression atom based on the token
  def exp_find_by_token(exp, token, parent_is_not = false)
    if exp.is_a?(Array)                             # Is this and AND or OR
      exp.each do |e|                               #   yes, check each array item
        ret_exp = exp_find_by_token(e, token)       # Look for token
        return ret_exp if ret_exp != nil            # Return if we found it
      end
      return nil                                    # Didn't find it in the array, return nil
    elsif exp[:token] && exp[:token] == token       # This is the token exp
      @parent_is_not = true if parent_is_not        # Remember that token exp's parent is a NOT
      return exp                                    #   return it
    elsif exp["not"]
      return exp_find_by_token(exp["not"], token, true) # Look for token under NOT (indicate we are a NOT)
    elsif exp["and"]
      return exp_find_by_token(exp["and"], token)   # Look for token under AND
    elsif exp["or"]
      return exp_find_by_token(exp["or"], token)    # Look for token under OR
    else
      return nil
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
      @edit[@expkey][:exp_available_cfields] = Array.new                # Create the check fields pulldown array
      MiqExpression.miq_adv_search_lists(@edit[@expkey][:exp_model], :exp_available_finds).each do |af|
        if af.last.split("-").first == @edit[@expkey][:exp_field].split("-").first
          @edit[@expkey][:exp_available_cfields].push([af.first.split(":").last, af.last]) # Include fields from the chosen table
        end
      end
      @edit[@expkey][:exp_value] = exp[key]["search"][skey]["value"]    # Get the search value
      if exp[key].has_key?("checkall")                        # Find the check hash key
        chk = @edit[@expkey][:exp_check] = "checkall"
      elsif exp[key].has_key?("checkany")
        chk = @edit[@expkey][:exp_check] = "checkany"
      elsif exp[key].has_key?("checkcount")
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
          exp[joiner] = [{key=>exp[key]}]             # Chain in the current key under the joiner array
          exp.delete(key)                             # Remove the current key
          exp[joiner].push({"???"=>"???"})            # Add in the new key under the joiner
        end
      end
      return
    else
      exp.each do |key, value|                        # Go thru the next level down
        next if key == :token                         # Skip the :token key
        case key.upcase
        when "AND", "OR"                              # If AND or OR, check all array items
          if key.downcase != joiner                   # Does the and/or match the joiner?
            exp[key].each_with_index do |item, idx|   # No,
              exp_add_joiner(item, token, joiner)     #   check the lower expressions
            end
          else
            exp[key].each_with_index do |item, idx|   # Yes,
              if item[:token] && item[:token] == token  # Found the match
                exp[key].insert(idx + 1, {"???"=>"???"})  # Add in the new key hash
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
        next if exp[key] == nil                       # Check for the key already gone
        exp["not"] = Hash.new                         # Create the "not" hash
        exp["not"][key] = exp[key]                    # copy the found key's value down into the "not" hash
        exp.delete(key)                               # Remove the existing key
      end
    else
      exp.each do |key, value|                        # Go thru the next level down
        next if key == :token                         # Skip the :token key
        case key.upcase
        when "AND", "OR"                              # If AND or OR, check all array items
          exp[key].each_with_index do |item, idx|
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
      if @edit[@expkey][:exp_field] == nil
        add_flash(I18n.t("flash.edit.filter.must_be_chosen", :field=>"field"), :error)
      elsif @edit[@expkey][:exp_value] != :user_input &&
            e = MiqExpression.atom_error(@edit[@expkey][:exp_field],
                                         @edit[@expkey][:exp_key],
                                         @edit[@expkey][:exp_value].kind_of?(Array) ?
                                           @edit[@expkey][:exp_value] :
                                           (@edit[@expkey][:exp_value].to_s + (@edit[:suffix] ? ".#{@edit[:suffix].to_s}" : ""))
                                        )
        add_flash(I18n.t("flash.edit.filter.field_value_error", :field=>"Field", :msg=>e), :error)
      else
        # Change datetime and date values from single element arrays to text string
        if [:datetime, :date].include?(@edit[@expkey][:val1][:type])
          @edit[@expkey][:exp_value] = @edit[@expkey][:exp_value].first.to_s if @edit[@expkey][:exp_value].length == 1
        end

        exp.delete(@edit[@expkey][:exp_orig_key])                     # Remove the old exp fields
        exp[@edit[@expkey][:exp_key]] = Hash.new                        # Add in the new key
        exp[@edit[@expkey][:exp_key]]["field"] = @edit[@expkey][:exp_field]     # Set the field
        unless @edit[@expkey][:exp_key].include?("NULL") || @edit[@expkey][:exp_key].include?("EMPTY")  # Check for "IS/IS NOT NULL/EMPTY"
          exp[@edit[@expkey][:exp_key]]["value"] = @edit[@expkey][:exp_value]   #   else set the value
          unless exp[@edit[@expkey][:exp_key]]["value"] == :user_input
            exp[@edit[@expkey][:exp_key]]["value"] += ".#{@edit[:suffix].to_s}" if @edit[:suffix] # Append the suffix, if present
          end
        end
        exp[@edit[@expkey][:exp_key]]["alias"] = @edit[@expkey][:alias] if @edit.fetch_path(@expkey, :alias)
      end
    when "count"
      if @edit[@expkey][:exp_value] != :user_input &&
         e = MiqExpression.atom_error(:count, @edit[@expkey][:exp_key], @edit[@expkey][:exp_value])
        add_flash(I18n.t("flash.edit.filter.field_value_error", :field=>"Field", :msg=>e), :error)
      else
        exp.delete(@edit[@expkey][:exp_orig_key])                     # Remove the old exp fields
        exp[@edit[@expkey][:exp_key]] = Hash.new                        # Add in the new key
        exp[@edit[@expkey][:exp_key]]["count"] = @edit[@expkey][:exp_count]     # Set the count table
        exp[@edit[@expkey][:exp_key]]["value"] = @edit[@expkey][:exp_value]     # Set the value
        exp[@edit[@expkey][:exp_key]]["alias"] = @edit[@expkey][:alias] if @edit.fetch_path(@expkey, :alias)
      end
    when "tag"
      if @edit[@expkey][:exp_tag] == nil
        add_flash(I18n.t("flash.edit.filter.must_be_chosen", :field=>"tag category"), :error)
      elsif @edit[@expkey][:exp_value] == nil
        add_flash(I18n.t("flash.edit.filter.must_be_chosen", :field=>"tag value"), :error)
      else
        exp.delete(@edit[@expkey][:exp_orig_key])                     # Remove the old exp fields
        exp[@edit[@expkey][:exp_key]] = Hash.new                        # Add in the new key
        exp[@edit[@expkey][:exp_key]]["tag"] = @edit[@expkey][:exp_tag]         # Set the tag
        exp[@edit[@expkey][:exp_key]]["value"] = @edit[@expkey][:exp_value]     # Set the value
        exp[@edit[@expkey][:exp_key]]["alias"] = @edit[@expkey][:alias] if @edit.fetch_path(@expkey, :alias)
      end
    when "regkey"
      if @edit[@expkey][:exp_regkey].blank?
        add_flash(I18n.t("flash.edit.filter.must_be_entered", :field=>"registry key name"), :error)
      elsif @edit[@expkey][:exp_regval].blank? && @edit[@expkey][:exp_key] != "KEY EXISTS"
        add_flash(I18n.t("flash.edit.filter.must_be_entered", :field=>"registry value name"), :error)
      elsif @edit[@expkey][:exp_key] == "RUBY" && e = MiqExpression.atom_error(:ruby, @edit[@expkey][:exp_key], @edit[@expkey][:exp_value])
        add_flash(I18n.t("flash.edit.filter.field_value_error", :field=>"Registry", :msg=>e), :error)
      elsif @edit[@expkey][:exp_key].include?("REGULAR EXPRESSION") && e = MiqExpression.atom_error(:regexp, @edit[@expkey][:exp_key], @edit[@expkey][:exp_value])
        add_flash(I18n.t("flash.edit.filter.field_value_error", :field=>"Registry", :msg=>e), :error)
      else
        exp.delete(@edit[@expkey][:exp_orig_key])                     # Remove the old exp fields
        exp[@edit[@expkey][:exp_key]] = Hash.new                        # Add in the new key
        exp[@edit[@expkey][:exp_key]]["regkey"] = @edit[@expkey][:exp_regkey]   # Set the key name
        unless  @edit[@expkey][:exp_key].include?("KEY EXISTS")
          exp[@edit[@expkey][:exp_key]]["regval"] = @edit[@expkey][:exp_regval] # Set the value name
        end
        unless  @edit[@expkey][:exp_key].include?("NULL") ||            # Check for "IS/IS NOT NULL/EMPTY" or "EXISTS"
                @edit[@expkey][:exp_key].include?("EMPTY") ||
                @edit[@expkey][:exp_key].include?("EXISTS")
          exp[@edit[@expkey][:exp_key]]["value"] = @edit[@expkey][:exp_value]   #   else set the data value
        end
      end
    when "find"
      if @edit[@expkey][:exp_field] == nil
        add_flash(I18n.t("flash.edit.filter.must_be_chosen", :field=>"find field"), :error)
      elsif ["checkall","checkany"].include?(@edit[@expkey][:exp_check]) &&
            @edit[@expkey][:exp_cfield] == nil
        add_flash(I18n.t("flash.edit.filter.must_be_chosen", :field=>"check field"), :error)
      elsif @edit[@expkey][:exp_check] == "checkcount" &&
            (@edit[@expkey][:exp_cvalue] == nil || is_integer?(@edit[@expkey][:exp_cvalue]) == false)
        add_flash(I18n.t("flash.edit.filter.must_be_integer"), :error)
      elsif e = MiqExpression.atom_error(@edit[@expkey][:exp_field],
                                        @edit[@expkey][:exp_skey],
                                        @edit[@expkey][:exp_value].kind_of?(Array) ?
                                          @edit[@expkey][:exp_value] :
                                          (@edit[@expkey][:exp_value].to_s + (@edit[:suffix] ? ".#{@edit[:suffix].to_s}" : ""))
                                        )
        add_flash(I18n.t("flash.edit.filter.field_value_error", :field=>"Find", :msg=>e), :error)
      elsif e = MiqExpression.atom_error(@edit[@expkey][:exp_check] == "checkcount" ? :count : @edit[@expkey][:exp_cfield],
                                        @edit[@expkey][:exp_ckey],
                                        @edit[@expkey][:exp_cvalue].kind_of?(Array) ?
                                          @edit[@expkey][:exp_cvalue] :
                                          (@edit[@expkey][:exp_cvalue].to_s + (@edit[:suffix2] ? ".#{@edit[:suffix2].to_s}" : ""))
                                        )
        add_flash(I18n.t("flash.edit.filter.field_value_error", :field=>"Check", :msg=>e), :error)
      else
        # Change datetime and date values from single element arrays to text string
        if [:datetime, :date].include?(@edit[@expkey][:val1][:type])
          @edit[@expkey][:exp_value] = @edit[@expkey][:exp_value].first.to_s if @edit[@expkey][:exp_value].length == 1
        end
        if @edit[@expkey][:val2][:type] && [:datetime, :date].include?(@edit[@expkey][:val2][:type])
          @edit[@expkey][:exp_cvalue] = @edit[@expkey][:exp_cvalue].first.to_s if @edit[@expkey][:exp_cvalue].length == 1
        end

        exp.delete(@edit[@expkey][:exp_orig_key])                     # Remove the old exp fields
        exp[@edit[@expkey][:exp_key]] = Hash.new                        # Add in the new key
        exp[@edit[@expkey][:exp_key]]["search"] = Hash.new              # Create the search hash
        skey = @edit[@expkey][:exp_skey]
        exp[@edit[@expkey][:exp_key]]["search"][skey] = Hash.new        # Create the search operator hash
        exp[@edit[@expkey][:exp_key]]["search"][skey]["field"] = @edit[@expkey][:exp_field] # Set the search field
        unless skey.include?("NULL") || skey.include?("EMPTY")  # Check for "IS/IS NOT NULL/EMPTY"
          exp[@edit[@expkey][:exp_key]]["search"][skey]["value"] = @edit[@expkey][:exp_value] #   else set the value
          exp[@edit[@expkey][:exp_key]]["search"][skey]["value"] += ".#{@edit[:suffix].to_s}" if @edit[:suffix] # Append the suffix, if present
        end
        chk = @edit[@expkey][:exp_check]
        exp[@edit[@expkey][:exp_key]][chk] = Hash.new                 # Create the check hash
        ckey = @edit[@expkey][:exp_ckey]
        exp[@edit[@expkey][:exp_key]][chk][ckey] = Hash.new           # Create the check operator hash
        if @edit[@expkey][:exp_check] == "checkcount"
          exp[@edit[@expkey][:exp_key]][chk][ckey]["field"] = "<count>" # Indicate count is being checked
        else
          exp[@edit[@expkey][:exp_key]][chk][ckey]["field"] = @edit[@expkey][:exp_cfield] # Set the check field
        end
        unless ckey.include?("NULL") || ckey.include?("EMPTY")  # Check for "IS/IS NOT NULL/EMPTY"
          exp[@edit[@expkey][:exp_key]][chk][ckey]["value"] = @edit[@expkey][:exp_cvalue] #   else set the value
          exp[@edit[@expkey][:exp_key]][chk][ckey]["value"] += ".#{@edit[:suffix2].to_s}" if @edit[:suffix2]  # Append the suffix, if present
        end
        exp[@edit[@expkey][:exp_key]]["search"][skey]["alias"] = @edit[@expkey][:alias] if @edit.fetch_path(@expkey, :alias)
      end
    else
      add_flash(I18n.t("flash.edit.filter.select_expression_element_type"), :error)
      add_flash(I18n.t("flash.edit.select_required", :selection=>"Expression element type"), :error)
    end
  end

  # Remove an expression part based on the token
  def exp_remove(exp, token)
    if exp[:token] && exp[:token] == token              # If the token matches
      return true                                       #   Tell caller to remove me
    else
      keepkey, keepval, deletekey = nil                 # Holders for key, value pair to keep and key to delete
      exp.each do |key, value|                          # Go thru each exp element
        next if key == :token                           # Skip the :token keys
        case key.upcase
        when "AND", "OR"                                # If AND or OR
          exp[key].each_with_index do |item, idx|       #   check all array items
            if exp_remove(item, token) == true          # See if this part should be removed
              if item.has_key?("not")                   # The item to remove is a NOT
                exp[key].insert(idx+1,item["not"])      # Rechain the NOT child into the array
                exp[key].delete_at(idx)                 # Remove the NOT item
              else                                      # Item to remove is other than a NOT
                exp[key].delete_at(idx)                 # Remove it from the array
                if exp[key].length == 1                 # If only 1 part left
                  exp[key][0].each do |k,v|             # Find the key that's not :token
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
    @edit[@expkey][:exp_array] ||= Array.new
    exp_ary = @edit[@expkey][:exp_array]          # Put exp array in local var
    exp_idx = @edit[@expkey][:exp_idx]            # Put exp index in local var
    case func
    when :init
      exp_ary = @edit[@expkey][:exp_array] = Array.new      # Clear/create the exp array
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
    return nil                                    # Return nil if no exp was returned
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
      @edit = Hash.new
      @edit[@expkey] ||= Hash.new                                       # Create hash for this expression, if needed
      @edit[@expkey][:expression] = Array.new                           # Store exps in an array
      @edit[@expkey][:exp_idx] = 0                                      # Start at first exp
      @edit[@expkey][:expression] = {"???"=>"???"}                      # Set as new exp element
      @edit[@expkey][:use_mytags] = true                                # Include mytags in tag search atoms
      @edit[:custom_search] = false                                     # setting default to false
      @edit[:new] = Hash.new
      @edit[:new][@expkey] = @edit[@expkey][:expression]                # Copy to new exp
      exp_array(:init, @edit[@expkey][:expression])                     # Initialize the exp array
      @edit[:adv_search_open] = false
      @edit[@expkey][:exp_model] = model.to_s
      @edit[:flash_div_num] = "2"
    end
    @edit[@expkey][:exp_table] = exp_build_table(@edit[@expkey][:expression]) # Build the table to display the exp
    @edit[:in_explorer] = @explorer # Remember if we're in an explorer

    if @hist && @hist[:qs_exp] # Override qs exp if qs history button was pressed
      @edit[:adv_search_applied] = {:text=>@hist[:text], :qs_exp=>@hist[:qs_exp]}
      session[:adv_search][model.to_s] = copy_hash(@edit) # Save updated adv_search options
    end
  end

  # Build the pulldown lists for the adv search box
  def adv_search_build_lists
    # converting expressions into Array here, so Global views can be pushed into it and be shown on the top with Global Prefix in load pull down
    global_expressions = MiqSearch.get_expressions(:db=>@edit[@expkey][:exp_model],
                                                                        :search_type=>"global")
    @edit[@expkey][:exp_search_expressions] = MiqSearch.get_expressions(:db=>@edit[@expkey][:exp_model],
                                                                        :search_type=>"user",
                                                                        :search_key=>session[:userid])
    @edit[@expkey][:exp_search_expressions] = Array(@edit[@expkey][:exp_search_expressions]).sort
    global_expressions = Array(global_expressions).sort if !global_expressions.blank?
    if !global_expressions.blank?
      global_expressions.each_with_index do |ge,i|
        global_expressions[i][0] = "Global - #{ge[0]}"
        @edit[@expkey][:exp_search_expressions] = @edit[@expkey][:exp_search_expressions].unshift(global_expressions[i])
      end
    end
  end

  # Build a string from an array of expression symbols by recursively traversing the MiqExpression object
  #   and inserting sequential tokens for each expression part
  def exp_build_string(exp)
    exp_string = ""
    exp_tooltip = ""      #string for tooltip without fonts tags
    if exp["and"]
      fcolor = calculate_font_color(exp["result"])
      exp_string << "<font color=#{fcolor}><b>(</b></font>"
      exp_tooltip << "("
      exp["and"].each do |e|
        fcolor = calculate_font_color(e["result"])
        exp_str,exp_tip = exp_build_string(e)
        if exp["result"] && !e["result"]
          exp_string << "<font color=#{fcolor}><i>" << exp_str << "</i></font>"
        else
          exp_string << "<font color=#{fcolor}>" << exp_str << "</font>"
        end
        exp_tooltip << exp_tip
        fcolor = calculate_font_color(exp["result"])
        exp_string << "<font color=#{fcolor}> <b>AND</b> </font>" unless e ==exp["and"].last
        exp_tooltip << " AND " unless e ==exp["and"].last
      end
      exp_string << "<font color=#{fcolor}><b>)</b></font>"
      exp_tooltip << ")"
    elsif exp["or"]
      fcolor = calculate_font_color(exp["result"])
      exp_string << "<font color=#{fcolor}><b>(</b></font>"
      exp["or"].each do |e|
        fcolor = calculate_font_color(e["result"])
        exp_str,exp_tip = exp_build_string(e)
        if exp["result"] && !e["result"]
          exp_string << "<font color=#{fcolor}><i>" << exp_str << "</i></font>"
        else
          exp_string << "<font color=#{fcolor}>" << exp_str << "</font>"
        end
        exp_tooltip << exp_tip
        fcolor = calculate_font_color(exp["result"])
        exp_string << "<font color=#{fcolor}> <b>OR</b> </font>" unless e ==exp["or"].last
        exp_tooltip << " OR " unless e ==exp["or"].last
      end
      exp_string << "<font color=#{fcolor}><b>)</b></font>"
      exp_tooltip << ")"
    elsif exp["not"]
      fcolor = calculate_font_color(exp["result"])
      exp_string << "<font color=#{fcolor}> <b>NOT</b> </font>"
      exp_tooltip << " NOT "
      exp_string << "<font color=#{fcolor}><b>(</b></font>" if !["and","or"].include?(exp["not"].keys.first)  # No parens if and/or under me
      exp_tooltip << "(" if !["and","or"].include?(exp["not"].keys.first) # No parens if and/or under me
      exp_str,exp_tip = exp_build_string(exp["not"])
      if exp["result"] && !exp["not"]["result"]
        exp_string << "<font color=#{fcolor}><i>" << exp_str << "</i></font>"
      else
        exp_string << "<font color=#{fcolor}>" << exp_str << "</font>"
      end

      exp_tooltip << exp_tip
      exp_string << "<font color=#{fcolor}><b>)</b></font>" if !["and","or"].include?(exp["not"].keys.first)  # No parens if and/or under me
      exp_tooltip << ")" if !["and","or"].include?(exp["not"].keys.first) # No parens if and/or under me
    else
      fcolor = calculate_font_color(exp["result"])
      temp_exp = copy_hash(exp)
      temp_exp.delete("result")
      exp_string << "<font color=#{fcolor}>" << MiqExpression.to_human(temp_exp) << "</font>"
      exp_tooltip <<  MiqExpression.to_human(temp_exp)
    end
    return exp_string,exp_tooltip
  end

  def calculate_font_color(result)
    fcolor = "black"
    if result == true
      fcolor = "green"
    elsif result == false
      fcolor = "red"
    end
    return fcolor
  end

  def build_listnav_search_list(db)
    @settings[:default_search] = User.find_by_userid(session[:userid]).settings[:default_search]  # Get the user's default search settings again, incase default search was deleted
    @default_search = MiqSearch.find(@settings[:default_search][db.to_sym].to_s) if @settings[:default_search] && @settings[:default_search][db.to_sym] && @settings[:default_search][db.to_sym] != 0 && MiqSearch.exists?(@settings[:default_search][db.to_sym])
    temp = MiqSearch.new
    temp.description = "ALL"
    temp.id = 0
    @def_searches = MiqSearch.all(:conditions=>["(search_type=? or (search_type=? and (search_key is null or search_key<>?))) and db=?", "global","default","_hidden_",db]).sort{|a,b| a.description.downcase<=>b.description.downcase}
    @def_searches = @def_searches.unshift(temp) if !@def_searches.blank?
    @my_searches = MiqSearch.all(:conditions=>["search_type=? and search_key=? and db=?", "user",session[:userid],db]).sort{|a,b| a.description.downcase<=>b.description.downcase}
  end

  def process_changed_expression(params, chosen_key, exp_key, exp_value, exp_valx)

    if [ params[chosen_key], @edit[@expkey][exp_key] ].include?("RUBY")      # Clear the value if going to/from RUBY
      @edit[@expkey][exp_value] = nil
      @edit[:suffix] = nil
    end

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
        @edit[@expkey][exp_value_key] = @edit[@expkey][value_key][:date_format] == "s" ? Array.new : [EXP_TODAY]
      end
    end
  end
  private :process_datetime_expression_field

end
