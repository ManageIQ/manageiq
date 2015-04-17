module ReportHelper
  STYLE_CLASSES = {
    :miq_rpt_red_text     => "Red Text",
    :miq_rpt_red_bg       => "Red Background",
    :miq_rpt_yellow_text  => "Yellow Text",
    :miq_rpt_yellow_bg    => "Yellow Background",
    :miq_rpt_green_text   => "Green Text",
    :miq_rpt_green_bg     => "Green Background",
    :miq_rpt_blue_text    => "Blue Text",
    :miq_rpt_blue_bg      => "Blue Background",
    :miq_rpt_maroon_text  => "Light Blue Text",
    :miq_rpt_maroon_bg    => "Light Blue Background",
    :miq_rpt_purple_text  => "Purple Text",
    :miq_rpt_purple_bg    => "Purple Background",
    :miq_rpt_gray_text    => "Gray Text",
    :miq_rpt_gray_bg      => "Gray Background"
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
end
