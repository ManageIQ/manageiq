module MiqReport::Generator::Html
  def build_html_rows(clickable_rows = false)
    tz = get_time_zone(Time.zone.name) if Time.zone
    html_rows = []
    counter = 0
    group_counter = 0
    row = 0

    self.rpt_options ||= {}
    self.col_formats ||= []                  # Backward compat - create empty array for formats
    group_limit = self.rpt_options[:group_limit]
    in_a_widget = self.rpt_options[:in_a_widget] || false

    unless table.nil? || table.data.length == 0
      # Following line commented for now - for not showing repeating column values
      #       prev_data = String.new                # Initialize the prev_data variable

      tot_cpu = tot_ram = tot_space = tot_disk = tot_net = 0.0 if db == "VimUsage"  # Create usage total cols

      cfg = VMDB::Config.new("vmdb").config[:reporting]       # Read in the reporting column precisions
      default_precision = cfg[:precision][:default]           # Set the default
      precision_by_column = cfg[:precision_by_column]         # get the column overrides
      precisions = {}                                         # Hash to store columns we hit
      hide_detail_rows = self.rpt_options.fetch_path(:summary, :hide_detail_rows) || false

      # derive a default precision by looking at the suffixes of the column hearers
      zero_precision_suffixes = ["(ms)", "(mb)", "(seconds)", "(b)"]
      headers.each_with_index do |header, i|
        next unless header.respond_to?(:downcase)
        header = header.downcase
        zero_precision_suffixes.each do |s|
          if header.ends_with?(s) && precision_by_column[col_order[i]].blank?
            precisions[col_order[i]] = 0
            break
          end
        end
      end

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
          group_text = d.data["display_range"] if db == "Chargeback" && sortby[0] == "start_date" # Chargeback, sort by date, but show range
        end

        # Build click thru if string can be created
        if clickable_rows && onclick = build_row_onclick(d.data)
          output << "<tr class='row#{row}' #{onclick}>"
        else
          output << "<tr class='row#{row}-nocursor'>"
        end
        row = 1 - row

        col_order.each_with_index do |c, c_idx|
          style = get_style_class(c, d.data, tz)
          style_class = !style.nil? ? " class='#{style}'" : nil
          if c == "resource_type"                     # Lookup models in resource_type col
            output << "<td#{style_class}>"
            output << ui_lookup(:model => d.data[c])
            output << "</td>"
          elsif db == "VimUsage"                 # Format usage columns
            case c
            when "cpu_usagemhz_rate_average"
              output << "<td#{style_class} " + 'style="text-align:right">'
              output << CGI.escapeHTML(format(c, d.data[c].to_f, :format => :general_number_precision_1))
              tot_cpu += d.data[c].to_f
            when "derived_memory_used"
              output << "<td#{style_class} " + 'style="text-align:right">'
              output << CGI.escapeHTML(format(c, d.data[c].to_f, :format => :megabytes_human))
              tot_ram += d.data[c].to_f
            when "derived_vm_used_disk_storage"
              output << "<td#{style_class} " + 'style="text-align:right">'
              output << CGI.escapeHTML(format(c, d.data[c], :format => :bytes_human))
              tot_space += d.data[c].to_f
            when "derived_storage_used_managed"
              output << "<td#{style_class} " + 'style="text-align:right">'
              output << CGI.escapeHTML(format(c, d.data[c], :format => :bytes_human))
              tot_space += d.data[c].to_f
            when "disk_usage_rate_average"
              output << "<td#{style_class} " + 'style="text-align:right">'
              output << CGI.escapeHTML(format(c, d.data[c].to_f, :format => :general_number_precision_1)) <<
                " (#{CGI.escapeHTML(format(c, d.data[c].to_f * 1.kilobyte * extras[:interval], :format => :bytes_human))})"
              tot_disk += d.data[c].to_f
            when "net_usage_rate_average"
              output << "<td#{style_class} " + 'style="text-align:right">'
              output << CGI.escapeHTML(format(c, d.data[c].to_f, :format => :general_number_precision_1)) <<
                " (#{CGI.escapeHTML(format(c, d.data[c].to_f * 1.kilobyte * extras[:interval], :format => :bytes_human))})"
              tot_net += d.data[c].to_f
            else
              output << "<td#{style_class}>"
              output << d.data[c].to_s
            end
            output << "</td>"
          elsif ["<compare>", "<drift>"].include?(db.to_s)
            output << "<td#{style_class}>"
            output << CGI.escapeHTML(d.data[c].to_s)
            output << "</td>"
          else
            if d.data[c].kind_of?(Time)
              output << "<td#{style_class} " + 'style="text-align:center">'
            elsif d.data[c].kind_of?(Bignum) || d.data[c].kind_of?(Fixnum) || d.data[c].kind_of?(Float)
              output << "<td#{style_class} " + 'style="text-align:right">'
            else
              output << "<td#{style_class}>"
            end
            output << CGI.escapeHTML(format(c.split("__").first,
                                            d.data[c],
                                            :format => self.col_formats[c_idx] ? self.col_formats[c_idx] : :_default_,
                                            :tz     => tz))
            output << "</td>"
          end
        end

        output << "</tr>"

        html_rows << output unless hide_detail_rows
      end

      if db == "VimUsage"                    # Output usage totals
        output = ""
        if row == 0
          output << '<tr class="row0">'
          row = 1
        else
          output << '<tr class="row1">'
          row = 0
        end
        output << "<td><strong>Totals:</strong></td>"
        col_order.each do |c|
          case c
          when "cpu_usagemhz_rate_average"
            output << '<td style="text-align:right"><strong>' <<
              CGI.escapeHTML(format(c, tot_cpu, :format => :general_number_precision_1)) <<
              "</strong></td>"
          when "derived_memory_used"
            output << '<td style="text-align:right"><strong>' <<
              CGI.escapeHTML(format(c, tot_ram, :format => :megabytes_human)) <<
              "</strong></td>"
          when "derived_storage_used_managed"
            output << '<td style="text-align:right"><strong>' <<
              CGI.escapeHTML(format(c, tot_space, :format => :bytes_human)) <<
              "</strong></td>"
          when "derived_vm_used_disk_storage"
            output << '<td style="text-align:right"><strong>' <<
              CGI.escapeHTML(format(c, tot_space, :format => :bytes_human)) <<
              "</strong></td>"
          when "disk_usage_rate_average"
            output << '<td style="text-align:right"><strong>' << CGI.escapeHTML(format(c, tot_disk, :format => :general_number_precision_1)) <<
              " (#{CGI.escapeHTML(format(c, tot_disk * 1.kilobyte * extras[:interval], :format => :bytes_human))})" << "</strong></td>"
          when "net_usage_rate_average"
            output << '<td style="text-align:right"><strong>' << CGI.escapeHTML(format(c, tot_net, :format => :general_number_precision_1)) <<
              " (#{CGI.escapeHTML(format(c, tot_net * 1.kilobyte * extras[:interval], :format => :bytes_human))})" << "</strong></td>"
          end
        end
        output << "</tr>"

        html_rows << output
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

  # Depending on the model the table is based on, return the onclick string for the report row
  def build_row_onclick(data_row)
    onclick = nil

    # Handle CI based report rows
    if ['EmsCluster', 'ExtManagementSystem', 'Host', 'Repository', 'Storage', 'Vm', 'Service'].include?(db) && data_row['id']
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
        "All Rows"
      else
        group_label = group_text || group
        group_label = "<Empty>" if group_label.blank?
        "#{label}#{group_label}"
      end

    display_count = "Count: #{extras[:grouping][group][:count]}" if (self.group == 'c') && extras && extras[:grouping] && extras[:grouping][group]
    content << " | #{display_count}" unless display_count.blank?
    html_rows << "<tr><td class='group' colspan='#{col_count}'>#{CGI.escapeHTML(content)}</td></tr>"

    if extras && extras[:grouping] && extras[:grouping][group] # See if group key exists
      MiqReport::GROUPINGS.each do |calc|                     # Add an output row for each group calculation
        if extras[:grouping][group].key?(calc.first) # Only add a row if there are calcs of this type for this group value
          grp_output = ""
          grp_output << "<tr>"
          grp_output << "<td#{in_a_widget ? "" : " class='group'"} style='text-align:right'>#{calc.last.pluralize}:</td>"
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

    nh = {}; row.each { |k, v| nh[col_to_expression_col(k).sub(/-/, ".")] = v } # Convert keys to match expression fields
    field = col_to_expression_col(col)

    atoms.each do |atom|
      return atom[:class] if atom[:operator].downcase == "default"

      exp = expression_for_style_class(field, atom)
      return atom[:class] if exp.evaluate(nh, {}, tz)
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
