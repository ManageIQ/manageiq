module ReportFormatter
  class ReportHTML < Ruport::Formatter
    renders :html, :for => ReportRenderer

    def build_html_title
      mri = options.mri
      mri.html_title = ''
      mri.html_title << " <div style='height: 10px;'></div>"
      mri.html_title << "<ul id='tab'>"
      mri.html_title << "<li class='active'><a class='active'>"
      mri.html_title << " #{mri.title}" unless mri.title.nil?
      mri.html_title << "</a></li></ul>"
      mri.html_title << '<div class="clr"></div><div class="clr"></div><div class="b"><div class="b"><div class="b"></div></div></div>'
      mri.html_title << '<div id="element-box"><div class="t"><div class="t"><div class="t"></div></div></div><div class="m">'
    end

    def pad(str, len)
      return "".ljust(len) if str.nil?
      str = str.slice(0, len) # truncate long strings
      str.ljust(len) # pad with whitespace
    end

    def build_document_header
      build_html_title
    end

    def build_document_body
      mri = options.mri
      tz = mri.get_time_zone(Time.zone.name)
      output << "<table class='table table-striped table-bordered'>"
      output << "<thead>"
      output << "<tr>"

      # table heading
      unless mri.headers.nil?
        mri.headers.each do |h|
          output << "<th>" << CGI.escapeHTML(h.to_s) << "</th>"
        end
        output << "</tr>"
        output << "</thead>"
      end
      output << '<tbody>'

      # table data
      #     save_val = nil
      counter = 0
      row = 0
      unless mri.table.nil?

        # Following line commented for now - for not showing repeating column values
        #       prev_data = String.new                # Initialize the prev_data variable

        precision_by_column = ::Settings.reporting.precision_by_column # get the column overrides
        precisions = {} # Hash to store columns we hit

        # derive a default precision by looking at the suffixes of the column hearers
        zero_precision_suffixes = ["(ms)", "(mb)", "(seconds)", "(b)"]
        mri.headers.each_index do |i|
          zero_precision_suffixes.each do |s|
            if  mri.headers[i].downcase.ends_with?(s) && precision_by_column[mri.col_order[i]].blank?
              precisions[mri.col_order[i]] = 0
              break
            end
          end
        end

        row_limit = mri.rpt_options && mri.rpt_options[:row_limit] ? mri.rpt_options[:row_limit] : 0
        save_val = :_undefined_                                 # Hang on to the current group value
        group_text = nil                                        # Optionally override what gets displayed for the group (i.e. Chargeback)
        use_table = mri.sub_table ? mri.sub_table : mri.table
        use_table.data.each_with_index do |d, d_idx|
          break if row_limit != 0 && d_idx > row_limit - 1
          if ["y", "c"].include?(mri.group) && !mri.sortby.nil? && save_val != d.data[mri.sortby[0]].to_s
            unless d_idx == 0                       # If not the first row, we are at a group break
              output << group_rows(save_val, mri.col_order.length, group_text)
            end
            save_val = d.data[mri.sortby[0]].to_s
            # Chargeback, sort by date, but show range
            group_text = d.data["display_range"] if Chargeback.db_is_chargeback?(db) && mri.sortby[0] == "start_date"
          end

          if row == 0
            output << '<tr class="row0 no-hover">'
            row = 1
          else
            output << '<tr class="row1 no-hover">'
            row = 0
          end
          mri.col_formats ||= []                 # Backward compat - create empty array for formats
          mri.col_order.each_with_index do |c, c_idx|
            if c == "resource_type"                     # Lookup models in resource_type col
              output << '<td>'
              output << ui_lookup(:model => d.data[c])
              output << "</td>"
            else
              if d.data[c].kind_of?(Time)
                output << '<td style="text-align:center">'
              elsif d.data[c].kind_of?(Bignum) || d.data[c].kind_of?(Fixnum) || d.data[c].kind_of?(Float)
                output << '<td style="text-align:right">'
              else
                output << '<td>'
              end
              output << CGI.escapeHTML(mri.format(c.split("__").first,
                                                  d.data[c],
                                                  :format => mri.col_formats[c_idx] ? mri.col_formats[c_idx] : :_default_,
                                                  :tz     => tz))
              output << "</td>"
            end
          end

          output << "</tr>"
        end
      end

      if ["y", "c"].include?(mri.group) && !mri.sortby.nil?
        output << group_rows(save_val, mri.col_order.length, group_text)
        output << group_rows(:_total_, mri.col_order.length)
      end

      output << '</tbody>'
    end

    # Generate grouping rows for the passed in grouping value
    def group_rows(group, col_count, group_text = nil)
      mri = options.mri
      grp_output = ""
      if mri.extras[:grouping] && mri.extras[:grouping][group]  # See if group key exists
        if mri.group == "c"                                     # Show counts row
          if group == :_total_
            grp_output << "<tr><td class='group' colspan='#{col_count}'>Count for All Rows: #{mri.extras[:grouping][group][:count]}</td></tr>"
          else
            g = group_text ? group_text : group
            grp_output << "<tr><td class='group' colspan='#{col_count}'>Count for #{g.blank? ? "&lt;blank&gt;" : g}: #{mri.extras[:grouping][group][:count]}</td></tr>"
          end
        else
          if group == :_total_
            grp_output << "<tr><td class='group' colspan='#{col_count}'>All Rows</td></tr>"
          else
            g = group_text ? group_text : group
            grp_output << "<tr><td class='group' colspan='#{col_count}'>#{g.blank? ? "<blank>" : g}&nbsp;</td></tr>"
          end
        end
        MiqReport::GROUPINGS.each do |calc|                     # Add an output row for each group calculation
          if mri.extras[:grouping][group].key?(calc.first)  # Only add a row if there are calcs of this type for this group value
            grp_output << "<tr>"
            grp_output << "<td class='group'>#{calc.last.pluralize}:</td>"
            mri.col_order.each_with_index do |c, c_idx|         # Go through the columns
              next if c_idx == 0                                # Skip first column
              grp_output << "<td class='group' style='text-align:right'>"
              grp_output << CGI.escapeHTML(mri.format(c.split("__").first,
                                                      mri.extras[:grouping][group][calc.first][c],
                                                      :format => mri.col_formats[c_idx] ? mri.col_formats[c_idx] : :_default_
                                                     )
                                          ) if mri.extras[:grouping][group].key?(calc.first)
              grp_output << "</td>"
            end
            grp_output << "</tr>"
          end
        end
      end
      grp_output << "<tr><td class='group' colspan='#{col_count}'>&nbsp;</td></tr>" unless group == :_total_
      grp_output
    end

    def build_document_footer
      mri = options.mri
      output << "<tfoot>"
      output << "<td colspan='15'>"
      output << "<del class='container'>"
      # output << "<div class='pagination'>"
      # output << '<div class="limit">Display #<select name="limit" id="limit" class="inputbox" size="1" onchange="submitform();"><option value="5" >5</option><option value="10" >10</option><option value="15" >15</option><option value="20"  selected="selected">20</option><option value="25" >25</option><option value="30" >30</option><option value="50" >50</option><option value="100" >100</option><option value="0" >all</option></select></div>'
      # output << '<div class="button2-right off"><div class="start"><span>Start</span></div></div><div class="button2-right off"><div class="prev"><span>Prev</span></div></div>'
      # output << ""
      # output << ""
      # output << "<div class='button2-left'><div class='page'>"
      # output << "<a title='1' onclick='javascript: document.adminForm.limitstart.value=0; submitform();return false;'>1</a>"
      # output << "<a title='2' onclick='javascript: document.adminForm.limitstart.value=20; submitform();return false;'>2</a>"
      # output << "</div></div>"

      # output << "<div class='button2-left'><div class='next'>"
      #  output << "<a title='Next' onclick='javascript: document.adminForm.limitstart.value=20; submitform();return false;'>Next</a>"
      #  output << "</div></div>"

      #  output << '<div class="button2-left"><div class="end"><a title="End" onclick="javascript: document.adminForm.limitstart.value=40; submitform();return false;">End</a></div></div>'

      #  output << "<div class='limit'>page 1 of 3</div><input type='hidden' name='limitstart' value='0' /></div>"
      output << "</del>"
      output << "</td>"
      output << "</tfoot>"
      output << "</table>"

      if mri.filter_summary
        output << mri.filter_summary.to_s
      end

      #     output << "<div class='clr'></div>"
      #     output << "</div>"
      #     output << "<div class='b'>"
      #     output << "<div class='b'>"
      #     output << "<div class='b'></div>"
      #     output << "</div>"
      #     output << "</div>"
      #     output << "</div>"
    end

    def finalize_document
      output
    end
  end
end
