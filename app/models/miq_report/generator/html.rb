module MiqReport::Generator::Html
  def build_html_rows(clickable_rows = false)
    time_zone = get_time_zone(Time.zone)
    html_rows = []
    group_counter = 0
    row = 0

    self.rpt_options ||= {}
    self.col_formats ||= []                  # Backward compat - create empty array for formats
    group_limit = self.rpt_options[:group_limit]
    in_a_widget = self.rpt_options[:in_a_widget] || false

    unless table.nil? || table.data.empty?
      # Following line commented for now - for not showing repeating column values
      #       prev_data = String.new                # Initialize the prev_data variable

      hide_detail_rows = self.rpt_options.fetch_path(:summary, :hide_detail_rows) || false

      row_limit = self.rpt_options && self.rpt_options[:row_limit] ? self.rpt_options[:row_limit] : 0
      save_val = :_undefined_                                 # Hang on to the current group value
      break_label = col_options.fetch_path(sortby[0], :break_label) unless sortby.nil? || col_options.nil? || in_a_widget
      group_text = nil                                        # Optionally override what gets displayed for the group (i.e. Chargeback)
      use_table = sub_table ? sub_table : table
      use_table.data.each_with_index do |d, d_idx|
        break if row_limit != 0 && d_idx > row_limit - 1
        output = ""
        if ["y", "c"].include?(group) && !sortby.nil? && save_val != d.data[sortby[0]].to_s
          unless d_idx == 0                       # If not the first row, we are at a group break
            unless group_limit && group_counter >= group_limit  # If not past the limit
              html_rows += build_group_html_rows(save_val, col_order.length, break_label, group_text)
              group_counter += 1
            end
          end
          save_val = d.data[sortby[0]].to_s
          # Chargeback, sort by date, but show range
          group_text = d.data["display_range"] if Chargeback.db_is_chargeback?(db) && sortby[0] == "start_date"
        end

        # Build click thru if string can be created
        if clickable_rows && onclick = build_row_onclick(d.data)
          output << "<tr class='row#{row}' #{onclick}>"
        else
          output << "<tr class='row#{row}-nocursor'>"
        end
        row = 1 - row

        col_order.each_with_index do |c, c_idx|
          next if column_is_hidden?(c)

          build_html_col(output, c, self.col_formats[c_idx], d.data, time_zone)
        end

        output << "</tr>"

        html_rows << output unless hide_detail_rows
      end

      if ["y", "c"].include?(group) && !sortby.nil?
        unless group_limit && group_counter >= group_limit
          html_rows += build_group_html_rows(save_val, col_order.length, break_label, group_text)
          html_rows += build_group_html_rows(:_total_, col_order.length)
        end
      end
    end

    html_rows
  end

  def format_column(col_name, row_data, time_zone, col_format = nil)
    if col_name == 'resource_type'
      ui_lookup(:model => row_data[col_name]) # Lookup models in resource_type col
    elsif db == 'Tenant' && TenantQuota.can_format_field?(col_name, row_data['tenant_quotas.name'])
      CGI.escapeHTML(TenantQuota.format_quota_value(col_name, row_data[col_name], row_data['tenant_quotas.name']))
    elsif ['<compare>', '<drift>'].include?(db.to_s)
      CGI.escapeHTML(row_data[col_name].to_s)
    else
      CGI.escapeHTML(format(col_name.split("__").first, row_data[col_name], :format => col_format || :_default_, :tz => time_zone)) # rubocop:disable Style/FormatString
    end
  end

  def open_td(style_class, text_align = nil)
    alignment_style = case text_align
                      when :right
                        ' style="text-align:right"'
                      when :center
                        ' style="text-align:center"'
                      else
                        ''
                      end

    "<td#{style_class}#{alignment_style}>"
  end

  def build_html_col(output, col_name, col_format, row_data, time_zone)
    style = get_style_class(col_name, row_data, time_zone)
    style_class = !style.nil? ? " class='#{style}'" : nil
    alignment_style = if db == 'Tenant' && TenantQuota.can_format_field?(col_name, row_data['tenant_quotas.name']) || row_data[col_name].kind_of?(Integer) || row_data[col_name].kind_of?(Float)
                        :right
                      elsif row_data[col_name].kind_of?(Time)
                        :center
                      end

    output << open_td(style_class, alignment_style)
    output << format_column(col_name, row_data, time_zone, col_format)
    output << '</td>'
  end

  # Depending on the model the table is based on, return the onclick string for the report row
  def build_row_onclick(data_row)
    onclick = nil

    # Handle CI based report rows
    if ['EmsCluster', 'ExtManagementSystem', 'Host', 'Storage', 'Vm', 'Service'].include?(db) && data_row['id']
      controller = db == "ExtManagementSystem" ? "management_system" : db.underscore
      donav = "DoNav('/#{controller}/show/#{data_row['id']}');"
      title = data_row['name'] ?
        "View #{ui_lookup(:model => db)} \"#{data_row['name']}\"" :
        "View this #{ui_lookup(:model => db)}"
      onclick = "onclick=\"#{donav}\" style='cursor:hand' title='#{title}'"
    end

    # Handle CI performance report rows
    if db.ends_with?("Performance")
      if data_row['resource_id'] && data_row['resource_type'] # Base click thru on the related resource
        donav = "DoNav('/#{data_row['resource_type'].underscore}/show/#{data_row['resource_id']}');"
        onclick = "onclick=\"#{donav}\" style='cursor:hand' title='View #{ui_lookup(:model => data_row['resource_type'])} \"#{data_row['resource_name']}\"'"
      end
    end

    onclick
  end

  # Generate grouping rows for the passed in grouping value
  def build_group_html_rows(group, col_count, label = nil, group_text = nil)
    in_a_widget = self.rpt_options[:in_a_widget] || false

    html_rows = []

    content =
      if group == :_total_
        _("All Rows")
      else
        group_label = group_text || group
        group_label = _("<Empty>") if group_label.blank?
        "#{label}#{group_label}"
      end

    if (self.group == 'c') && extras && extras[:grouping] && extras[:grouping][group]
      display_count = _("Count: %{number}") % {:number => extras[:grouping][group][:count]}
    end
    content << " | #{display_count}" unless display_count.blank?
    html_rows << "<tr><td class='group' colspan='#{col_count}'>#{CGI.escapeHTML(content)}</td></tr>"

    if extras && extras[:grouping] && extras[:grouping][group] # See if group key exists
      MiqReport::GROUPINGS.each do |calc|                     # Add an output row for each group calculation
        if extras[:grouping][group].key?(calc.first) # Only add a row if there are calcs of this type for this group value
          grp_output = ""
          grp_output << "<tr>"
          grp_output << "<td#{in_a_widget ? "" : " class='group'"} style='text-align:right'>#{_(calc.last)}:</td>"
          col_order.each_with_index do |c, c_idx|        # Go through the columns
            next if c_idx == 0                                # Skip first column
            grp_output << "<td#{in_a_widget ? "" : " class='group'"} style='text-align:right'>"
            grp_output << CGI.escapeHTML(
              format(
                c.split("__").first, extras[:grouping][group][calc.first][c],
                :format => self.col_formats[c_idx] ? self.col_formats[c_idx] : :_default_
              )
            ) if extras[:grouping][group].key?(calc.first)
            grp_output << "</td>"
          end
          grp_output << "</tr>"
          html_rows << grp_output
        end
      end
    end
    html_rows << "<tr><td class='group_spacer' colspan='#{col_count}'>&nbsp;</td></tr>" unless group == :_total_
    html_rows
  end

  def get_style_class(col, row, tz = nil)
    atoms = col_options.fetch_path(col, :style) unless col_options.nil?
    return if atoms.nil?

    nh = {}
    row.each { |k, v| nh[col_to_expression_col(k).sub(/-/, ".")] = v } # Convert keys to match expression fields
    field = col_to_expression_col(col)

    atoms.each do |atom|
      return atom[:class] if atom[:operator].downcase == "default"

      exp = expression_for_style_class(field, atom)
      return atom[:class] if exp.evaluate(nh, tz)
    end
    nil
  end

  def expression_for_style_class(field, atom)
    @expression_for_style_class ||= {}
    @expression_for_style_class[field] ||= {}

    value = atom[:value]
    value = [value, atom[:value_suffix]].join(".").to_f_with_method if atom[:value_suffix] && value.to_f.respond_to?(atom[:value_suffix])
    @expression_for_style_class[field][atom] ||= MiqExpression.new({atom[:operator] => {"field" => field, "value" => value}}, "hash")
  end
end
