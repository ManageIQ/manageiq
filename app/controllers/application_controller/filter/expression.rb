module ApplicationController::Filter
  Expression = Struct.new(
    :alias,
    :expression,
    :exp_array,
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
    :exp_idx,
    :exp_key,
    :exp_last_loaded,
    :exp_mode,
    :exp_model,
    :exp_orig_key,
    :exp_regkey,
    :exp_regval,
    :exp_skey,
    :exp_search_expressions,
    :exp_table,
    :exp_tag,
    :exp_token,
    :exp_typ,
    :exp_value,
    :pre_qs_selected,
    :use_mytags,
    :selected,
    :val1,
    :val1_suffix,
    :val2,
    :val2_suffix,
    :record_filter
  ) do
    def exp_available_cfields # fields on exp_model for check_all, check_any, and check_count operation
      MiqExpression.miq_adv_search_lists(exp_model, :exp_available_finds).each_with_object([]) do |af, res|
        next if af.last == exp_field
        next unless af.last.split('-').first == exp_field.split('-').first
        res.push([af.first.split(':').last, af.last])
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

    def set_exp_typ(chosen_typ)
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

    private

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

    private

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
  end
  # TODO: expression is now manipulated with fetch_path
  # We need to extract methods using fetch_path to Expression to avoid the fetch_path call
  ApplicationController::Filter::Expression.send(:include, MoreCoreExtensions::Shared::Nested)
end
