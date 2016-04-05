module ChartingHelper
  def chart_remote(a_controller, options)
    case Charting.backend
    when :ziya
      ziya_chart(url_for(:controller => a_controller,
                         :action     => options[:action] || 'render_chart',
                         :width      => options[:width],
                         :height     => options[:height],
                         :rand       => "#{rand(999_999_999)}"),
                 options.slice(:id, :bgcolor, :width, :height))
    when :jqplot
      jqplot_remote(url_for(:controller => a_controller,
                            :action     => options[:action] || 'render_chart',
                            :width      => options[:width],
                            :height     => options[:height],
                            :rand       => "#{rand(999_999_999)}"),
                    options.slice(:id, :bgcolor, :width, :height))
    when :c3
      c3chart_remote(url_for(:controller => a_controller,
                             :action     => options[:action] || 'render_chart'),
                     options.slice(:id))
    end
  end

  def chart_no_url(options)
    case Charting.backend
    when :ziya   then ziya_chart(nil, options.slice(:id, :bgcolor, :width, :height))
    when :jqplot then jqplot_sample(options.slice(:id, :bgcolor, :width, :height))
    when :c3     then content_tag(:div, '', :id => options[:id])
    end
  end

  # FIXME: ziya cannot pass data in-line?
  # if it can then fix app/views/dashboard/_widget_chart.html.erb
  def chart_local(data, options)
    case Charting.backend
    when :ziya   then ziya_chart(nil, options.slice(:id, :bgcolor, :width, :height))
    when :jqplot then jqplot(data, options.slice(:id, :bgcolor, :width, :height))
    when :c3     then c3chart_local(data, options.slice(:id))
    end
  end
end
