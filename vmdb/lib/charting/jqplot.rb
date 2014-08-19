class Jqplot
  # FIXME: move to a different dir or change the charting/* loading
  class << self
    def default_legend(chart)
      chart[:options].update(:legend => {:show => true, :location => 'e', :fontSize => '8px'})
      chart
    end

    def horizontal_legend(chart)
      chart[:options].update(:legend => {
        :renderer        => 'jQuery.jqplot.EnhancedLegendRenderer',
        :show            => true,
        :location        => 'n',
        :fontSize        => '10px',
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
      # when 'PieThreed'
      else
        {
          :data    => [[nil]],
          :options => {
            :title  => "Invalid char type #{chart_type}",
            :series => []
          }
        }
      end
    end

    def apply_theme(chart, report_theme)
      Rails.logger.error(['Jqplot apply_theme', chart, report_theme].inspect)
      chart
    end
  end
end
