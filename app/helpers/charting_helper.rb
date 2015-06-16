module ChartingHelper
  def chart_remote(a_controller, options)
    p :chart_remote
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
    elsif Charting.backend == :c3
      c3chart_remote(url_for(:controller => a_controller,
          :action => options[:action] || 'render_chart',
        ),
        options.slice(:id))
    end
  end

  def chart_no_url(options)
    p :chart_no_url
    if Charting.backend == :ziya
      ziya_chart(nil, options.slice(:id, :bgcolor, :width, :height))
    elsif Charting.backend == :jqplot
      jqplot_sample(options.slice(:id, :bgcolor, :width, :height))
    elsif Charting.backend == :c3
      c3chart_sample
    end
  end

  # FIXME: ziya cannot pass data in-line?
  # if it can then fix app/views/dashboard/_widget_chart.html.erb
  def chart_local(data, options)
    p :chart_local
    if Charting.backend == :ziya
      ziya_chart(nil, options.slice(:id, :bgcolor, :width, :height))
    elsif Charting.backend == :jqplot
      jqplot(data, options.slice(:id, :bgcolor, :width, :height))
    elsif Charting.backend == :c3
      c3chart_local(data, options.slice(:id))
    end
  end
end
