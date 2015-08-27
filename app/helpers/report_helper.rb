module ReportHelper
  STYLE_CLASSES = {
    :miq_rpt_red_text    => "Red Text",
    :miq_rpt_red_bg      => "Red Background",
    :miq_rpt_yellow_text => "Yellow Text",
    :miq_rpt_yellow_bg   => "Yellow Background",
    :miq_rpt_green_text  => "Green Text",
    :miq_rpt_green_bg    => "Green Background",
    :miq_rpt_blue_text   => "Blue Text",
    :miq_rpt_blue_bg     => "Blue Background",
    :miq_rpt_maroon_text => "Light Blue Text",
    :miq_rpt_maroon_bg   => "Light Blue Background",
    :miq_rpt_purple_text => "Purple Text",
    :miq_rpt_purple_bg   => "Purple Background",
    :miq_rpt_gray_text   => "Gray Text",
    :miq_rpt_gray_bg     => "Gray Background"
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
    if @edit[:new][:group] != 'No'
      groupings = @edit[:new][:col_options].find_all do |_field, col_options|
        col_options[:grouping].present? && !col_options[:grouping].empty?
      end
      groupings.each_with_object([]) do |(field, col_options), options|
        model = @edit[:new][:model]
        col_options[:grouping].each do |fun|
          options << ["#{field} (#{fun.to_s.titleize})", "#{model}-#{field}:#{fun}"]
        end
      end
    else
      @edit[:new][:field_order].find_all do |f|
        ci = MiqReport.get_col_info(f.last.split("__").first)
        ci[:numeric]
      end
    end
  end

  # We allow value-based charts when we have aggregations or
  # simple charts w/o summary.
  def chart_mode_values_allowed?
    @edit[:new][:group] != 'Counts'
  end
end
