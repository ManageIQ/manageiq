module MiqReport::Formatters::Csv
  def to_csv
    return if (@sub_table || @table).nil?
    csv_table = @sub_table ? @sub_table.dup : @table.dup  # Duplicate table/sub_table since we will be deleting the ID column
    csv_table.column_names.delete("id")

    hidden_columns = csv_table.column_names.select { |column| column_is_hidden?(column) }

    rpt_options ||= {}
    csv_table = csv_table.sub_table(0..rpt_options[:row_limit] - 1) unless rpt_options[:row_limit].blank? # Get only row_limit rows
    csv_table.data.each do |key|
      key.data.each do |k|
        if k[0] == "v_date"
          key.data[k[0]] = k[1].in_time_zone(get_time_zone("UTC")).strftime("%m/%d/%Y %Z")
        elsif k[0] == "v_time"
          key.data[k[0]] = k[1].in_time_zone(get_time_zone("UTC")).strftime("%H:%M %Z")
        elsif k[1].kind_of?(Time)
          key.data[k[0]] = format_timezone(k[1], Time.zone, "gtl")
        end
      end

      key.data.except!(*(%w[id] + hidden_columns))
    end

    header_line = headers_for_output(hidden_columns).collect { |h| '"' + h + '"' }.join(",") + "\n"
    csv_table.reorder(col_order - hidden_columns) # csv orders by cols, then includes . . . reorder using our col_order array
    header_line + csv_table.as(:csv, :show_table_headers => false)
  end

  def headers_for_output(hidden_columns)
    headers.reject.each_with_index do |_, index|
      column = col_order[index]
      hidden_columns.include?(column)
    end
  end
end
