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

  # We allow value-based charts when we have aggregations or
  # simple charts w/o summary.
  def chart_mode_values_allowed?
    @edit[:new][:group] != 'Counts'
  end
end
