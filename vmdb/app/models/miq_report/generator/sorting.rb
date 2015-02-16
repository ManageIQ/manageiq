module MiqReport::Generator::Sorting
  SORT_COL_SUFFIX = "_sort_"

  def sort_table(table, col_names, order)
    # => Add special sorting logic here
    # => table     - Ruport::Data::Table. This class includes enumerable so it can be accessed as a collection of Ruport::Data::Record objects
    # => col_names - Array of column names to be sorted
    # => order     - Sort order: "Ascending" | "Descending"
    return table.sort_rows_by(col_names, order)
  end

  def build_sort_table
    return if self.sortby.nil?                                                # Are there any sort fields

    new_sortby = self.build_sort_suffix_data
    sb_nil_sub = []
    new_sortby.each_with_index do |sb,idx|
      base_col_name = sb.split(SORT_COL_SUFFIX).first
      ctype = self.class.get_col_type(self.col_to_expression_col(base_col_name)) || :string
      sb_nil_sub[idx] = case ctype
      when :string, :text, :boolean             then "00ff".hex.chr
      when :integer, :fixnum, :decimal, :float  then @table.data.collect { |d| d.data[sb] }.compact.max.to_i + 1
      when :datetime                            then Time.at(@table.data.collect { |d| d.data[sb] }.compact.max.to_i + 1).utc
      when :date                                then max = @table.data.collect { |d| d.data[sb] }.compact.max; max.nil? ? nil : max + 1
      end
    end

    new_sortby.each_with_index do |sb,idx|
      @table.data.each {|d|
        # Substitute any nils in the sort columns of the table so the sort doesn't crash
        d.data[sb] = sb_nil_sub[idx] if d.data[sb].nil?
        # Convert any booleans to string so the sort doesn't crash
        d.data[sb] = d.data[sb].to_s if d.data[sb].is_a?(FalseClass) || d.data[sb].is_a?(TrueClass)
      }
    end

    order = self.order.blank? ? "Ascending" : self.order                        # Default to Ascending sort
    @table = sort_table(@table, new_sortby, :order => order.downcase.to_sym)      # Sort the table

    # Remove any subtituted values we put in the table earlier
    new_sortby.each_with_index do |sb,idx|
      next if sb_nil_sub[idx].nil?
      @table.data.each {|d| d.data[sb] = nil if d.data[sb] == sb_nil_sub[idx]}
    end
  end

  def build_sort_suffix_data
    new_sortby = []
    rpt_sortby = self.sortby.to_miq_a
    rpt_sortby.each do |sb|
      col, sfx = sb.split("__")
      if sfx && self.class.is_break_suffix?(sfx)
        sort_col = "#{sb}#{SORT_COL_SUFFIX}"

        @table.add_column(sort_col) { |d| self.build_value_for_sort_suffix(d.data[col], sfx) }
        @table.add_column(sb)       { |d| self.format(sb, d.data[col], :format => self.col_options ? self.col_options.fetch_path(sb, :break_format) : nil) }

        new_sortby << sort_col

        # Add actual column a secondary sort to force sorting within same hour, day, week, month, etc. Only if there are no additional sort columns
        new_sortby << col if sb == rpt_sortby.last
      else
        new_sortby << sb
      end
    end

    return new_sortby
  end

  def build_value_for_sort_suffix(value, suffix)
    value = value.in_time_zone(self.get_time_zone("UTC")) if value && value.kind_of?(Time)
    value = value.to_time.utc.beginning_of_day            if value && value.kind_of?(Date)
    suffix = suffix.to_sym if suffix

    case suffix
    when :hour
      if value
        ts_str = value.iso8601
        ts_str[14..18] = "00:00"
        Time.parse(ts_str)
      end
    when :day           then value ? value.beginning_of_day     : nil
    when :week          then value ? value.beginning_of_week    : nil
    when :month         then value ? value.beginning_of_month   : nil
    when :quarter       then value ? value.beginning_of_quarter : nil
    when :year          then value ? value.beginning_of_year    : nil
    when :hour_of_day   then value ? value.hour                 : 999
    when :day_of_week   then value ? value.wday                 : 999
    when :week_of_year  then value ? value.strftime("%W").to_i  : 999
    when :day_of_month  then value ? value.mday                 : 999
    when :month_of_year then value ? value.month                : 999
    else
      value.kind_of?(Time) ? value.iso8601 : value
    end
  end
end
