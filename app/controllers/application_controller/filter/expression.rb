module ApplicationController::Filter
  Expression = Struct.new(
    :alias,
    :expression,
    :exp_available_tags,
    :exp_available_fields,
    :exp_cfield,
    :exp_check,
    :exp_ckey,
    :exp_chosen_report,
    :exp_chosen_search,
    :exp_cvalue,
    :exp_count,
    :exp_field,
    :exp_key,
    :exp_last_loaded,
    :exp_mode,
    :exp_model,
    :exp_orig_key,
    :exp_regkey,
    :exp_regval,
    :exp_skey,
    :exp_table,
    :exp_tag,
    :exp_token,
    :exp_typ,
    :exp_value,
    :history,
    :pre_qs_selected,
    :use_mytags,
    :selected,
    :val1,
    :val1_suffix,
    :val2,
    :val2_suffix,
    :record_filter
  ) do
    def initialize(*args)
      super
      self.history ||= ExpressionEditHistory.new
    end

    def drop_cache
      @available_adv_searches = nil
    end

    def exp_available_cfields # fields on exp_model for check_all, check_any, and check_count operation
      MiqExpression.miq_adv_search_lists(exp_model, :exp_available_finds).each_with_object([]) do |af, res|
        next if af.last == exp_field
        next unless af.last.split('-').first == exp_field.split('-').first
        res.push([af.first.split(':').last, af.last])
      end
    end

    def available_adv_searches
      @available_adv_searches ||=
        begin
          global_expressions = MiqSearch.get_expressions(:db => exp_model, :search_type => 'global')
          user_expressions = MiqSearch.get_expressions(:db => exp_model, :search_type => 'user',
                                                       :search_key => User.current_user.userid)
          user_expressions = Array(user_expressions).sort
          global_expressions = Array(global_expressions).sort
          global_expressions.each { |ge| ge[0] = "Global - #{ge[0]}" }
          global_expressions + user_expressions
        end
    end

    def calendar_needed?
      [val1, val2].compact.any? { |val| [:date, :datetime].include? val[:type] }
    end

    def render_values_to(page)
      if val1.try(:type)
        page << "ManageIQ.expEditor.first.type = '#{val1[:type]}';"
        page << "ManageIQ.expEditor.first.title = '#{val1[:title]}';"
      end
      if val2.try(:type)
        page << "ManageIQ.expEditor.second.type = '#{val2[:type]}';"
        page << "ManageIQ.expEditor.second.title = '#{val2[:title]}';"
      end
    end

    def prefill_val_types
      self.val1 ||= {}
      self.val2 ||= {}
      val1[:type] = case exp_typ
                    when 'field'
                      if exp_key == EXP_IS && val1[:date_format] == 's'
                        :date
                      else
                        val_type_for(:exp_key, :exp_field)
                      end
                    when 'find'
                      if exp_skey == EXP_IS && val1[:date_format] == 's'
                        :date
                      else
                        val_type_for(:exp_skey, :exp_field)
                      end
                    when 'count'
                      :integer
                    when 'regkey'
                      :string
                    end
      val2[:type] = if exp_typ == 'find'
                      if exp_ckey && val2[:date_format] == 's'
                        :date
                      else
                        exp_check == 'checkcount' ? :integer : val_type_for(:exp_ckey, :exp_cfield)
                      end
                    end
      val1[:title] = MiqExpression::FORMAT_SUB_TYPES[val1[:type]][:title] if val1[:type]
      val2[:title] = MiqExpression::FORMAT_SUB_TYPES[val2[:type]][:title] if val2[:type]
    end

    def build_search(name_given_by_user, global_search, userid)
      if selected.nil? ||                                # if no search was loaded
         name_given_by_user != selected[:description] || # or user changed the name of loaded search
         selected[:typ] == 'default'                     # or loaded search is default search, save it as my search
        s = build_new_search(name_given_by_user)
        if global_search
          miq_search_set_details(s, :global, name_given_by_user)
        else
          miq_search_set_details(s, :user, name_given_by_user, userid)
        end
      else
        s = MiqSearch.find(selected[:id])
        if global_search
          unless s.name == "global_#{name_given_by_user}" # it was already global before
            s = build_new_search(name_given_by_user)
          end
          miq_search_set_details(s, :global, name_given_by_user)
        else
          unless s.name == "user_#{userid}_#{name_given_by_user}" # iw was already "My Search"
            s = build_new_search(name_given_by_user)
          end
        end
      end
      s
    end

    def select_filter(miq_search, last_loaded = false) # save the last search loaded
      self.selected = {:id => miq_search.id, :name => miq_search.name, :description => miq_search.description,
                       :typ => miq_search.search_type}
      self.exp_last_loaded = selected if last_loaded
    end

    def update_from_expression_editor(params)
      if params[:chosen_typ] && params[:chosen_typ] != exp_typ
        change_exp_typ(params[:chosen_typ])
      else
        case exp_typ
        when 'field'
          if params[:chosen_field] && params[:chosen_field] != exp_field
            self.exp_field = params[:chosen_field]
            self.exp_value = nil
            self.val1_suffix = nil
            if params[:chosen_field] == '<Choose>'
              self.exp_field = nil
              self.exp_key = nil
            else
              if exp_model != '_display_filter_' && MiqExpression::Field.parse(exp_field).plural?
                self.exp_key = 'CONTAINS' # CONTAINS is valid only for plural tables
              else
                self.exp_key = nil unless MiqExpression.get_col_operators(exp_field).include?(exp_key)
                self.exp_key ||= MiqExpression.get_col_operators(exp_field).first # Default to first operator
              end
              prefill_val_types
              process_datetime_expression_field(:val1, :exp_key, :exp_value)
            end
            self.alias = nil
          end

          if params[:chosen_key] && params[:chosen_key] != exp_key
            process_changed_expression(params, :chosen_key, :exp_key, :exp_value, :val1)
          end

          if params[:user_input]
            self.exp_value = params[:user_input] == '1' ? :user_input : ''
          end
        when 'count'
          if params[:chosen_count] && params[:chosen_count] != exp_count
            if params[:chosen_count] == '<Choose>'
              self.exp_count = nil
              self.exp_key = nil
              self.exp_value = nil
            else
              self.exp_count = params[:chosen_count]
              self.exp_key = nil unless MiqExpression.get_col_operators(:count).include?(exp_key)
              self.exp_key ||= MiqExpression.get_col_operators(:count).first
            end
            self.alias = nil
          end
          self.exp_key = params[:chosen_key] if params[:chosen_key]

          if params[:user_input]
            self.exp_value = params[:user_input] == '1' ? :user_input : nil
          end
        when 'tag'
          if params[:chosen_tag] && params[:chosen_tag] != exp_tag
            self.exp_tag = params[:chosen_tag] == '<Choose>' ? nil : params[:chosen_tag]
            self.exp_key = exp_model == '_display_filter_' ? '=' : 'CONTAINS'
            self.exp_value = nil
            self.alias = nil
          end

          if params[:user_input]
            self.exp_value = params[:user_input] == '1' ? :user_input : nil
          end
        when 'regkey'
          self.exp_regkey = params[:chosen_regkey] if params[:chosen_regkey]
          self.exp_regval = params[:chosen_regval] if params[:chosen_regval]
          self.exp_key = params[:chosen_key] if params[:chosen_key]
          prefill_val_types

        when 'find'
          if params[:chosen_field] && params[:chosen_field] != exp_field
            self.exp_field = params[:chosen_field]
            self.exp_value = nil
            self.val1_suffix = nil
            if params[:chosen_field] == '<Choose>'
              self.exp_field = nil
              self.exp_skey = nil
            else
              self.exp_skey = nil unless MiqExpression.get_col_operators(exp_field).include?(exp_skey)
              self.exp_skey ||= MiqExpression.get_col_operators(exp_field).first
              prefill_val_types
              process_datetime_expression_field(:val1, :exp_skey, :exp_value)
            end
            if (exp_cfield.present? && exp_field.present?) && # Clear expression check portion
               (exp_cfield == exp_field || # if find field matches check field
                exp_cfield.split('-').first != exp_field.split('-').first) # or user chose a different table field
              self.exp_check = 'checkall'
              self.exp_cfield = nil
              self.exp_ckey = nil
              self.exp_cvalue = nil
            end
            self.alias = nil
          end

          if params[:chosen_skey] && params[:chosen_skey] != exp_skey
            process_changed_expression(params, :chosen_skey, :exp_skey, :exp_value, :val1)
          end

          if params[:chosen_check] && params[:chosen_check] != exp_check
            self.exp_check = params[:chosen_check]
            self.exp_cfield = nil
            self.exp_ckey = exp_check == 'checkcount' ? '=' : nil
            self.exp_cvalue = nil
            self.val2_suffix = nil
          end
          if params[:chosen_cfield] && params[:chosen_cfield] != exp_cfield
            self.exp_cfield = params[:chosen_cfield]
            self.exp_cvalue = nil
            self.val2_suffix = nil
            if params[:chosen_cfield] == '<Choose>'
              self.exp_cfield = nil
              self.exp_ckey = nil
            else
              self.exp_ckey = nil unless MiqExpression.get_col_operators(exp_cfield).include?(exp_ckey)
              self.exp_ckey ||= MiqExpression.get_col_operators(exp_cfield).first
              prefill_val_types
              process_datetime_expression_field(:val2, :exp_ckey, :exp_cvalue)
            end
          end

          if params[:chosen_ckey] && params[:chosen_ckey] != exp_ckey
            process_changed_expression(params, :chosen_ckey, :exp_ckey, :exp_cvalue, :val2)
          end

          self.exp_cvalue = params[:chosen_cvalue] if params[:chosen_cvalue]
        end

        # Check the value field for all exp types
        if params[:chosen_value] && params[:chosen_value] != exp_value.to_s
          self.exp_value = params[:chosen_value] == '<Choose>' ? nil : params[:chosen_value]
        end

        # Use alias checkbox
        if params.key?(:use_alias)
          self.alias = if params[:use_alias] == '1'
                         case exp_typ
                         when 'field', 'find'
                           MiqExpression.value2human(exp_field).split(':').last
                         when 'tag'
                           MiqExpression.value2human(exp_tag).split(':').last
                         when 'count'
                           MiqExpression.value2human(exp_count).split('.').last
                         end.strip
                       end
        end

        # Check the alias field
        if params.key?(:alias) && params[:alias] != self.alias.to_s # Did the value change?
          self.alias = params[:alias].strip.blank? ? nil : params[:alias]
        end

        # Check incoming date and time values
        # Copy FIND exp_skey to exp_key so following IFs work properly
        self.exp_key = exp_skey if exp_typ == 'FIND'
        process_datetime_selector(params, '1_0', :exp_key)  # First date selector
        process_datetime_selector(params, '1_1')            # 2nd date selector, only on FROM
        process_datetime_selector(params, '2_0', :exp_ckey) # First date selector in FIND/CHECK
        process_datetime_selector(params, '2_1')            # 2nd date selector, only on FROM

        # Check incoming FROM/THROUGH date/time choice values
        if params[:chosen_from_1]
          exp_value[0] = params[:chosen_from_1]
          val1[:through_choices] = Expression.through_choices(params[:chosen_from_1])
          if (exp_typ == 'field' && exp_key == EXP_FROM) ||
             (exp_typ == 'find' && exp_skey == EXP_FROM)
            # If the through value is not in the through choices, set it to the first choice
            unless val1[:through_choices].include?(exp_value[1])
              exp_value[1] = val1[:through_choices].first
            end
          end
        end
        exp_value[1] = params[:chosen_through_1] if params[:chosen_through_1]

        if params[:chosen_from_2]
          exp_cvalue[0] = params[:chosen_from_2]
          val2[:through_choices] = Expression.through_choices(params[:chosen_from_2])
          if exp_ckey == EXP_FROM
            # If the through value is not in the through choices, set it to the first choice
            unless val2[:through_choices].include?(exp_cvalue[1])
              exp_cvalue[1] = val2[:through_choices].first
            end
          end
        end
        exp_cvalue[1] = params[:chosen_through_2] if params[:chosen_through_2]
      end

      # Check for changes in date format
      if params[:date_format_1] && exp_value.present?
        val1[:date_format] = params[:date_format_1]
        exp_value.collect! { |_| params[:date_format_1] == 's' ? nil : EXP_TODAY }
        val1[:through_choices] = Expression.through_choices(exp_value[0]) if params[:date_format_1] == 'r'
      end
      if params[:date_format_2] && exp_cvalue.present?
        val2[:date_format] = params[:date_format_2]
        exp_cvalue.collect! { |_| params[:date_format_2] == 's' ? nil : EXP_TODAY }
        val2[:through_choices] = Expression.through_choices(exp_cvalue[0]) if params[:date_format_2] == 'r'
      end

      # Check for suffixes changed
      self.val1_suffix = MiqExpression::BYTE_FORMAT_WHITELIST[params[:choosen_suffix]] if params[:choosen_suffix]
      self.val2_suffix = MiqExpression::BYTE_FORMAT_WHITELIST[params[:choosen_suffix2]] if params[:choosen_suffix2]
    end

    private

    def change_exp_typ(chosen_typ)
      self.exp_typ = chosen_typ
      self.exp_key = self.alias = self.exp_skey = self.exp_ckey = self.exp_value = self.exp_cvalue = nil
      self.exp_regkey = self.exp_regval = self.val1_suffix = self.val2_suffix = nil
      case exp_typ
      when '<Choose>'
        self.exp_typ = nil
      when 'field'
        self.exp_field = nil
      when 'count'
        self.exp_count = nil
        self.exp_key = MiqExpression.get_col_operators(:count).first
        prefill_val_types
      when 'tag'
        self.exp_tag = nil
        self.exp_key = 'CONTAINS'
      when 'regkey'
        self.exp_key = MiqExpression.get_col_operators(:regkey).first
        prefill_val_types
      when 'find'
        self.exp_field = nil
        self.exp_key = 'FIND'
        self.exp_check = 'checkall'
        self.exp_cfield = nil
      end
    end

    def process_changed_expression(params, chosen_key, exp_key, exp_value, exp_valx)
      # Remove the second exp_value if the operator changed from EXP_FROM
      self[exp_value].delete_at(1) if self[exp_key] == EXP_FROM

      # Set THROUGH value if changing to FROM
      if params[chosen_key] == EXP_FROM
        if self[exp_valx][:date_format] == 'r' # Format is relative
          self[exp_valx][:through_choices] = self.class.through_choices(self[exp_value][0])
          self[exp_value][1] = self[exp_valx][:through_choices].first
        else # Format is specific, just add second value
          self[exp_value][1] = nil
        end
      end

      self[exp_key] = params[chosen_key]
      prefill_val_types

      # Convert to/from "<date>" and "<date time>" strings in the exp_value array for specific date/times
      if self[exp_valx][:date_format] == 's'
        if [:datetime, :date].include?(self[exp_valx][:type])
          self[exp_value].each_with_index do |v, v_idx|
            next if v.blank?
            self[exp_value][v_idx] = if params[chosen_key] == EXP_IS || self[exp_valx][:type] == :date
                                       v.split(' ').first if v.include?(':')
                                     else
                                       v + ' 00:00' unless v.include?(':')
                                     end
          end
        end
      end
    end

    def process_datetime_expression_field(value_key, exp_key, exp_value_key)
      if [:date, :datetime].include?(self[value_key][:type]) # Seting value for date/time fields
        self[value_key][:date_format] ||= 'r'
        if self[exp_key] == EXP_FROM
          self[exp_value_key] = self[value_key][:date_format] == 's' ? Array.new(2) : [EXP_TODAY, EXP_TODAY]
          self[value_key][:through_choices] = [EXP_TODAY] if self[value_key][:date_format] == 'r'
        else
          self[exp_value_key] = self[value_key][:date_format] == 's' ? [] : [EXP_TODAY]
        end
      end
    end

    def process_datetime_selector(params, param_key_suffix, exp_key = nil)
      param_date_key  = "miq_date_#{param_key_suffix}".to_sym
      param_time_key  = "miq_time_#{param_key_suffix}".to_sym
      return unless params[param_date_key] || params[param_time_key]

      exp_value_index = param_key_suffix[-1].to_i
      value_key       = "val#{param_key_suffix[0]}".to_sym
      exp_value_key   = param_key_suffix.starts_with?('1') ? :exp_value : :exp_cvalue

      date = params[param_date_key] || (params[param_time_key] && self[exp_value_key][exp_value_index].split(' ').first)
      time = params[param_time_key] if params[param_time_key]

      if time.to_s.blank? && self[value_key][:type] == :datetime && self[exp_key] != EXP_IS
        time = '00:00' # If time is blank, add in midnight if needed
      end
      time = " #{time}" unless time.to_s.blank? # Prepend a blank, if time is non-blank

      self[exp_value_key][exp_value_index] = "#{date}#{time}"
    end

    def build_new_search(name_given_by_user)
      MiqSearch.new(:db => exp_model, :description => name_given_by_user)
    end

    def miq_search_set_details(search, type, name_given_by_user, userid = nil)
      search.update_attributes(
        :search_key  => userid,
        :name        => "#{type == :global ? 'global' : "user_#{userid}"}_#{name_given_by_user}",
        :search_type => type
      )
    end

    def val_type_for(key, field)
      if !self[key] || !self[field]
        nil
      elsif self[key].starts_with?('REG')
        :regexp
      else
        typ = MiqExpression.get_col_info(self[field])[:format_sub_type]
        if MiqExpression::FORMAT_SUB_TYPES.keys.include?(typ)
          typ
        else
          :string
        end
      end
    end

    def self.through_choices(from_choice) # Return the through_choices pulldown array for FROM datetime/date operators
      tc = if FROM_HOURS.include?(from_choice)
             FROM_HOURS
           elsif FROM_DAYS.include?(from_choice)
             FROM_DAYS
           elsif FROM_WEEKS.include?(from_choice)
             FROM_WEEKS
           elsif FROM_MONTHS.include?(from_choice)
             FROM_MONTHS
           elsif FROM_QUARTERS.include?(from_choice)
             FROM_QUARTERS
           elsif FROM_YEARS.include?(from_choice)
             FROM_YEARS
           end
      # Return the THROUGH choices based on the FROM choice
      tc[0..tc.index(from_choice)]
    end

    def self.prefix_by_dot(suffix)
      suffix ? ".#{suffix}" : ''
    end
  end
  # TODO: expression is now manipulated with fetch_path
  # We need to extract methods using fetch_path to Expression to avoid the fetch_path call
  ApplicationController::Filter::Expression.send(:include, MoreCoreExtensions::Shared::Nested)
end
