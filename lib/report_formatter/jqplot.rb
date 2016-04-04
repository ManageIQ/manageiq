module ReportFormatter
  class JqplotFormatter < Ruport::Formatter
    include MiqReport::Formatting

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

    def build_reporting_chart_other
      mri.chart.update(Jqplot.basic_chart_fallback(mri.graph[:type]))
      super
      simple_numeric_styling
    end

    def build_reporting_chart_dim2
      mri.chart.update(Jqplot.basic_chart_fallback(mri.graph[:type]))
      counts = super
      dim2_formating(counts.keys)
    end

    def build_planning_chart(maxcols, divider)
      return unless super
      horizontal_line_cursor
      default_legend
      mri.chart.store_path(:options, :seriesDefaults, :renderer, 'jQuery.jqplot.BarRenderer')
      x_axis_category_labels
    end

    def build_numeric_chart_grouped_2dim
      mri.chart.update(Jqplot.basic_chart_fallback(mri.graph[:type]))
      series_names = super
      dim2_formating(series_names)
      numeric_axis_formatter
    end

    def numeric_axis_formatter
      if mri.graph[:type] =~ /(Bar|Column)/
        custom_format   = Array(mri[:col_formats])[Array(mri[:col_order]).index(raw_column_name)]
        format, options = javascript_format(mri.graph[:column].split(/(?<!:):(?!:)/)[0], custom_format)
        return unless format

        axis_formatter = "ManageIQ.charts.formatters.#{format}.jqplot(#{options.to_json})"
        axis = mri.graph[:type] =~ /Column/ ? :yaxis : :xaxis
        mri.chart.store_path(:options, :axes, axis, :tickOptions, :formatter, axis_formatter)
      end
    end

    def dim2_formating(ticks)
      horizontal_legend if mri.graph[:type] =~ /Bar/
      default_legend    if mri.graph[:type] =~ /Column/

      if mri.graph[:type] =~ /Column/
        mri.chart[:options].update(
          :axes        => {
            :xaxis => {
              :renderer => 'jQuery.jqplot.CategoryAxisRenderer',
              :ticks    => ticks,
            },
          },
          :highlighter => {
            :show                 => true,
            :tooltipAxes          => 'y',
            :tooltipContentEditor => 'jqplot_xaxis_tick_highlight',
            :tooltipLocation      => 'n'
          }
        )
      elsif mri.graph[:type] =~ /Bar/
        mri.chart[:options].update(
          :axes        => {
            :yaxis => {
              :renderer => 'jQuery.jqplot.CategoryAxisRenderer',
              :ticks    => ticks,
            },
          },
          :highlighter => {
            :show                 => true,
            :tooltipAxes          => 'x',
            :tooltipContentEditor => 'jqplot_yaxis_tick_highlight',
            :tooltipLocation      => 'n'
          }
        )
      end
    end

    def build_numeric_chart_grouped
      mri.chart.update(Jqplot.basic_chart_fallback(mri.graph[:type]))
      super
      simple_numeric_styling
      numeric_axis_formatter
    end

    def build_numeric_chart_simple
      mri.chart.update(Jqplot.basic_chart_fallback(mri.graph[:type]))
      super
      simple_numeric_styling
      numeric_axis_formatter
    end

    def pie_highligher(values = false)
      mri.chart[:options].update(
        :highlighter    => {
          :show                 => true,
          :useAxesFormatters    => false,
          :tooltipAxes          => 'y',
          :tooltipContentEditor => values ? 'jqplot_pie_highlight_values' : 'jqplot_pie_highlight',
          :tooltipLocation      => 'n'
        }
      )
    end

    def simple_numeric_styling
      pie_highligher if pie_type?

      if mri.graph[:type] =~ /(Bar|Column)/
        mri.chart.store_path(:options, :seriesDefaults, :rendererOptions, :varyBarColor, true)
        axis_category_labels_ticks
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
