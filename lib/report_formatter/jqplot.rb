module ReportFormatter
  class JqplotFormatter < Ruport::Formatter
    include ActionView::Helpers::UrlHelper
    include ChartCommon
    renders :jqplot, :for => ReportRenderer

    # series handling methods
    def series_class
      JqplotSeries
    end

    def add_series(label, data)
      mri.chart[:data] << data
      add_series_label(label)
    end

    def add_axis_category_text(categories)
      mri.chart[:axis_category_text] << categories
    end

    def add_series_label(label)
      mri.chart[:options][:series] << {:label => label}
    end

    # report building methods
    def build_document_header
      super
      mri.chart = {
        :axis_category_text => [],
        :data               => [],
        :options            => {
          :series => []
        }
      }
    end

    def build_document_footer
      mri.chart = Jqplot.apply_theme(mri.chart, options.theme) unless options.theme.nil?
    end

    def no_records_found_chart(topic = "No records found for this chart")
      mri.chart = {
        :data    => [[nil]],
        :options => {:title => topic}
      }
    end

    # C&U performance charts (Cluster, Host, VM based)
    def build_performance_chart_area(maxcols, divider)
      super
      if mri.graph[:type] =~ /Stacked/
        horizontal_line_cursor
        mri.chart[:options].update(
          :stackSeries    => true,
          :seriesDefaults => {:fill => true},
        )
      elsif mri.graph[:type] =~ /Line/
        mri.chart[:options][:title] = '' # Optimize / Utilization / Details has no titles inside charts
        mri.chart.store_path(:options, :highlighter, :show, true)
        mri.chart.store_path(:options, :highlighter, :tooltipAxes, 'y')
      end

      horizontal_legend
      x_axis_category_labels

      mri.chart.store_path(:options, :axes, :yaxis, :min, 0)
    end

    def x_axis_category_labels
      return if Array(mri.chart[:axis_category_text]).empty?

      mri.chart[:data] = mri.chart[:data]
        .zip(mri.chart[:axis_category_text])
          .collect do |series, labels|
            (labels || mri.chart[:axis_category_text][0]).zip(series)
          end

      mri.chart.store_path(:options, :axes, :xaxis, :renderer, 'jQuery.jqplot.CategoryAxisRenderer')
    end

    def vertical?
      @vertical ||= mri.graph[:type] =~ /(Column)/
    end

    def axis_category_labels_ticks
      return if Array(mri.chart[:axis_category_text]).empty?

      axis = vertical? ? :xaxis : :yaxis
      mri.chart.store_path(:options, :axes, axis, :renderer, 'jQuery.jqplot.CategoryAxisRenderer')
      mri.chart.store_path(:options, :axes, axis, :ticks, mri.chart[:axis_category_text][0].collect { |l| slice_legend(l) })
      mri.chart.store_path(:options, :axes, axis, :tickRenderer, 'jQuery.jqplot.CanvasAxisTickRenderer')

      mri.chart.store_path(:options, :axes, axis, :tickOptions, :angle, -45.0) if vertical?
    end

    # Utilization timestamp charts
    def build_util_ts_chart_column
      return unless super
      horizontal_line_cursor
      horizontal_legend
      mri.chart.store_path(:options, :seriesDefaults, :renderer, 'jQuery.jqplot.BarRenderer')
      x_axis_category_labels
    end

    def build_reporting_chart_dim2
      counts = super # FIXME: counts are passed for now, should handle this in a better way
      default_legend
      mri.chart[:options].update(
        :stackSeries    => true,
        :seriesDefaults => {:renderer => 'jQuery.jqplot.BarRenderer'},
        :axes           => {
          :xaxis => {
            :renderer => 'jQuery.jqplot.CategoryAxisRenderer',
            :ticks    => counts.keys,
          },
        },
        :highlighter    => {
          :show                 => true,
          :tooltipAxes          => 'y',
          :tooltipContentEditor => "foobar = function(str, seriesIndex, pointIndex, plot) {
              return plot.options.axes.xaxis.ticks[pointIndex] + ' / ' +
                     plot.options.series[seriesIndex].label + ': ' +
                     str;
          }",
          :tooltipLocation      => 'n'
        }
      )
    end

    def build_planning_chart(maxcols, divider)
      return unless super
      horizontal_line_cursor
      default_legend
      mri.chart.store_path(:options, :seriesDefaults, :renderer, 'jQuery.jqplot.BarRenderer')
      x_axis_category_labels
    end

    def build_numeric_chart_grouped
      mri.chart.update(Jqplot.basic_chart_fallback(mri.graph[:type]))
      super
      simple_numeric_styling
    end

    def build_numeric_chart_simple
      mri.chart.update(Jqplot.basic_chart_fallback(mri.graph[:type]))
      super
      simple_numeric_styling
    end

    def simple_numeric_styling
      mri.chart[:options].update(
        :highlighter    => {
          :show                 => true,
          :useAxesFormatters    => false,
          :tooltipAxes          => 'y',
          :tooltipContentEditor => "foobar = function(str, seriesIndex, pointIndex, plot) {
              return plot.series[seriesIndex].data[pointIndex][0] + ': ' +
                     plot.series[seriesIndex].data[pointIndex][1];
          }",
          :tooltipLocation      => 'n'
        }
      ) if pie_type?


      if mri.graph[:type] =~ /(Bar|Column)/
        mri.chart.store_path(:options, :seriesDefaults, :rendererOptions, :varyBarColor, true)
        axis_category_labels_ticks
        #default_legend 
      end
    end

    def finalize_document
      mri.chart.delete(:axis_category_text)
      mri.chart[:options][:title] ||= mri.title if options.show_title
      mri.chart
    end

    # chart setting helper methods
    def default_legend
      Jqplot.default_legend(mri.chart)
    end

    def horizontal_legend
      Jqplot.horizontal_legend(mri.chart)
    end

    def horizontal_line_cursor
      Jqplot.horizontal_line_cursor(mri.chart)
    end
  end
end
