module ChartingHelper
  def chart_remote(a_controller, options)
    if Charting.backend == :ziya
      ziya_chart(url_for(:controller => a_controller,
                         :action => options[:action] || 'render_chart',
                         :width  => options[:width],
                         :height => options[:height],
                         :rand   => "#{rand(999_999_999)}"),
                 options.slice(:id, :bgcolor, :width, :height))

    elsif Charting.backend == :jqplot
      jqplot_remote(url_for(:controller => a_controller,
                            :action => options[:action] || 'render_chart',
                            :width  => options[:width],
                            :height => options[:height],
                            :rand   => "#{rand(999_999_999)}"),
                    options.slice(:id, :bgcolor, :width, :height))
    end
  end

  def chart_no_url(options)
    if Charting.backend == :ziya
      ziya_chart(nil, options.slice(:id, :bgcolor, :width, :height))
    elsif Charting.backend == :jqplot
      jqplot_sample(options.slice(:id, :bgcolor, :width, :height))
    end
  end

  # FIXME: ziya cannot pass data in-line?
  # if it can then fix app/views/dashboard/_widget_chart.html.erb
  def chart_local(data, options)
    if Charting.backend == :ziya
      ziya_chart(nil, options.slice(:id, :bgcolor, :width, :height))
    elsif Charting.backend == :jqplot
      jqplot(data, options.slice(:id, :bgcolor, :width, :height))
    end
  end
end
