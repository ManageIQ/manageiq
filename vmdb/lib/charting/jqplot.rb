class Jqplot
  # FIXME: move to a different dir or change the charting/* loading
  class << self
    def default_legend(chart)
      chart[:options].update(:legend => {
        :show     => true,
        :location => 'e',
        :renderer => 'jQuery.jqplot.EnhancedLegendRenderer'
      })
      chart
    end

    def horizontal_legend(chart)
      chart[:options].update(:legend => {
        :renderer        => 'jQuery.jqplot.EnhancedLegendRenderer',
        :show            => true,
        :location        => 'n',
        :rendererOptions => {:numberColumns => 3}
      })
      chart
    end

    def horizontal_line_cursor(chart)
      chart[:options].update(:cursor => {
          :show               => true,
          :showVerticalLine   => false,
          :showHorizontalLine => true,
      })
      chart
    end

    def basic_chart_fallback(chart_type)
      basic_chart(chart_type == 'PieThreed' ? 'Pie' : chart_type)
    end

    def basic_chart(chart_type)
      case chart_type
      when 'Bar'
        {
          :options => {
            :seriesDefaults => {
              :renderer        => 'jQuery.jqplot.BarRenderer',
              :rendererOptions => {:barDirection => 'horizontal'},
            },
            :series         => []
          },
          :data    => []
        }
      when 'StackedBar'
        {
          :options => {
            :stackSeries    => true,
            :seriesDefaults => {
              :renderer        => 'jQuery.jqplot.BarRenderer',
              :rendererOptions => {:barDirection => 'horizontal'},
            },
            :series         => []
          },
          :data    => []
        }
      when 'Column'
        {
          :options => {
            :seriesDefaults => {
              :renderer        => 'jQuery.jqplot.BarRenderer',
              :rendererOptions => {:barDirection => 'vertical'},
            },
            :series         => []
          },
          :data    => []
        }
      when 'StackedColumn'
        {
          :options => {
            :stackSeries    => true,
            :seriesDefaults => {
              :renderer        => 'jQuery.jqplot.BarRenderer',
              :rendererOptions => {:barDirection => 'vertical'},
            },
            :series         => []
          },
          :data    => []
        }
      # when 'ColumnThreed' 'ParallelThreedColumn' 'StackedThreedColumn'
      when 'Pie'
        Jqplot.default_legend(
          :options => {
            :seriesDefaults => {
              :renderer        => 'jQuery.jqplot.PieRenderer',
              :rendererOptions => {:showDataLabels => true}
            },
            :series         => []
          },
          :data    => []
        )
      when 'Donut'
        Jqplot.default_legend(
          :options => {
            :seriesDefaults => {
              :renderer        => 'jQuery.jqplot.DonutRenderer',
              :rendererOptions => {:showDataLabels => true}
            },
            :series         => []
          },
          :data    => []
        )
      # when 'PieThreed'
      else
        {
          :data    => [[nil]],
          :options => {
            :title  => "Invalid chart type #{chart_type}",
            :series => []
          }
        }
      end
    end

    def apply_theme(chart, theme_name)
      theme = JqplotThemes.get_theme(theme_name)
      return chart if theme.nil?

      chart[:options][:seriesColors] = theme[:seriesColors] if theme[:seriesColors]
      apply_theme_fragment(chart, theme, :seriesDefaults)
      apply_theme_fragment(chart, theme, :grid)
      apply_theme_fragment(chart, theme, :legend)
      chart
    end

    private

    def apply_theme_fragment(chart, theme, fragment_name)
      if theme[fragment_name]
        chart[:options][fragment_name] ||= {}
        chart[:options][fragment_name].deep_merge!(theme[fragment_name])
      end
    end
  end
end
