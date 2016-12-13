module ReportHelper
  STYLE_CLASSES = {
    :miq_rpt_red_text    => _("Red Text"),
    :miq_rpt_red_bg      => _("Red Background"),
    :miq_rpt_yellow_text => _("Yellow Text"),
    :miq_rpt_yellow_bg   => _("Yellow Background"),
    :miq_rpt_green_text  => _("Green Text"),
    :miq_rpt_green_bg    => _("Green Background"),
    :miq_rpt_blue_text   => _("Blue Text"),
    :miq_rpt_blue_bg     => _("Blue Background"),
    :miq_rpt_maroon_text => _("Light Blue Text"),
    :miq_rpt_maroon_bg   => _("Light Blue Background"),
    :miq_rpt_purple_text => _("Purple Text"),
    :miq_rpt_purple_bg   => _("Purple Background"),
    :miq_rpt_gray_text   => _("Gray Text"),
    :miq_rpt_gray_bg     => _("Gray Background")
  }

  def visibility_options(widget)
    typ = widget.visibility.keys.first
    values = widget.visibility.values.flatten
    if values.first == "_ALL_"
      _("To All Users")
    else
      _("By %{typ}: %{values}") % {:typ => typ.to_s.titleize, :values => values.join(',')}
    end
  end

  def chart_fields_options
    chart_data_columns = if @edit[:new][:group] != 'No'
                           groupings = @edit[:new][:col_options].find_all do |_field, col_options|
                             col_options[:grouping].present? && !col_options[:grouping].empty?
                           end
                           groupings.each_with_object([]) do |(field, col_options), options|
                             model = @edit[:new][:model]
                             col_options[:grouping].each do |fun|
                               field_key = if field =~ /\./
                                             f = field.sub('.', '-')
                                             "#{model}.#{f}"
                                           else
                                             "#{model}-#{field}"
                                           end
                               field_label = @edit[:new][:headers][field_key]
                               options << ["#{field_label} (#{fun.to_s.titleize})", "#{model}-#{field}:#{fun}"]
                             end
                           end
                         else
                           @edit[:new][:field_order].find_all do |f|
                             ci = MiqReport.get_col_info(f.last.split("__").first)
                             ci[:numeric]
                           end
                         end
    [[_("Nothing selected"), nil]] + chart_data_columns
  end

  def filter_performance_start_options
    start_array = []
    case @edit[:new][:perf_interval]
    when 'hourly'
      6.times { |i| start_array.push([pluralize(i + 1, 'day').to_s, (i + 1).days.to_s]) }
      4.times { |i| start_array.push([pluralize(i + 1, 'week').to_s, (i + 1).weeks.to_s]) }
      5.times { |i| start_array.push([pluralize(i + 2, 'month').to_s, (i + 1).months.to_s]) }
    when 'daily'
      5.times  { |i| start_array.push([pluralize(i + 2, 'day').to_s, (i + 2).days.to_s]) }
      3.times  { |i| start_array.push([pluralize((i + 1), 'week').to_s, (i + 1).weeks.to_s]) }
      11.times { |i| start_array.push([pluralize((i + 1), 'month').to_s, (i + 1).months.to_s]) }
      start_array.push(['1 year', 1.year.to_s])
    end
    start_array
  end

  def filter_performance_end_options
    end_array = []
    case @edit[:new][:perf_interval]
    when 'hourly'
      end_array += [
        ['Today', '0'],
        ['Yesterday', 1.day.to_s]
      ]
      5.times { |i| end_array.push(["#{i + 2} days ago", (i + 2).days.to_s]) }
      4.times { |i| end_array.push(["#{pluralize(i + 1, 'week')} ago", (i + 1).weeks.to_s]) }
      5.times { |i| end_array.push(["#{pluralize(i + 2, 'month')} ago", (i + 1).months.to_s]) }
    when 'daily'
      end_array += [
        ['Yesterday', '0'] # Start with yesterday, since we only allow full 24 hour days in daily trending
      ]
      5.times { |i| end_array.push(["#{i + 2} days ago", (i + 1).days.to_s]) }
      3.times { |i| end_array.push(["#{pluralize((i + 1), 'week')} ago", ((i + 1).weeks - 1.day).to_s]) }
      6.times { |i| end_array.push(["#{pluralize((i + 1), 'month')} ago", ((i + 1).months - 1.day).to_s]) }
    end
    end_array
  end

  # We allow value-based charts when we have aggregations or
  # simple charts w/o summary.
  def chart_mode_values_allowed?
    @edit[:new][:group] != 'Counts'
  end
end
