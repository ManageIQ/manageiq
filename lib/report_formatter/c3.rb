module ReportFormatter
  class C3Formatter < Ruport::Formatter
    include ActionView::Helpers::UrlHelper
    include ChartCommon
    include MiqReport::Formatting
    renders :c3, :for => ReportRenderer

    # series handling methods
    def series_class
      C3Series
    end

    CONVERT_TYPES = {
      "ColumnThreed"         => "Column",
      "ParallelThreedColumn" => "Column",
      "StackedThreedColumn"  => "StackedColumn",
      "PieThreed"            => "Pie",
      "AreaThreed"           => "Area",
      "StackedAreaThreed"    => "StackedArea"
    }
    def add_series(label, data)
      @counter ||= 0
      @counter += 1
      series_id = @counter.to_s

      if chart_is_2d?
        mri.chart[:data][:columns] << [series_id, *data.map { |a| a[:value] }]
        mri.chart[:data][:names][series_id] = label
      else
        mri.chart[:data][:columns] = data.collect { |a| [a[:tooltip], a[:value]] }
        data.each{ |a| mri.chart[:data][:names][a[:tooltip]] = slice_legend(a[:tooltip]) }
      end

      if chart_is_stacked?
        mri.chart[:data][:groups][0] << series_id
      end
    end

    def add_axis_category_text(categories)
      if chart_is_2d?
        mri.chart[:axis][:x][:categories] = categories
      end
    end

    # report building methods
    def build_document_header
      super
      type = c3_convert_type("#{mri.graph[:type]}")
      mri.chart = {
        :miqChart => type,
        :data     => {:columns => [], :names => {}},
        :axis     => {},
        :tooltip  => {}
      }

      if chart_is_2d?
        mri.chart[:axis] = {
          :x => {
            :categories => []
          }
        }
      end

      # chart is numeric
      if mri.graph[:mode] == 'values'
        custom_format   = Array(mri[:col_formats])[Array(mri[:col_order]).index(raw_column_name)]
        format, options = javascript_format(mri.graph[:column].split(/(?<!:):(?!:)/)[0], custom_format)
        return unless format

        axis_formatter = {:function => format, :options => options}
        mri.chart[:axis][:y] = {:tick => {:format => axis_formatter}}
      end

      if chart_is_stacked?
        mri.chart[:data][:groups] = [[]]
      end

      # C&U chart
      if graph_options[:chart_type] == :performance
        format, options = javascript_format(mri.graph[:columns][0], nil)
        return unless format

        axis_formatter = {:function => format, :options => options}
        mri.chart[:axis][:y] = {:tick => {:format => axis_formatter}}
      end
    end

    def c3_convert_type(type)
      CONVERT_TYPES[type] || type
    end

    def chart_is_2d?
      ['Bar', 'Column', 'StackedBar', 'StackedColumn', 'Line', 'Area', 'StackedArea'].include?(mri.graph[:type])
    end

    def chart_is_stacked?
      %w(StackedBar StackedColumn StackedArea).include?(mri.graph[:type])
    end

    # change structure of chart JSON to performance chart with timeseries data
    def build_performance_chart_area(maxcols, divider)
      super
      change_structure_to_timeseries
    end

    def no_records_found_chart(*)
      mri.chart = {
        :data => {
          :columns => []
        }
      }
    end

    def finalize_document
      mri.chart
    end

    private

    # change structure of hash from standard chart to timeseries chart
    def change_structure_to_timeseries
      # add 'x' as first element and move mri.chart[:axis][:x][:categories] to mri.chart[:data][:columns] as first column
      x = mri.chart[:axis][:x][:categories]
      x.unshift('x')
      mri.chart[:data][:columns].unshift(x)
      mri.chart[:data][:x] = 'x'
      # set x axis type to timeseries and remove categories
      mri.chart[:axis][:x] = {:type => 'timeseries', :tick => {}}
      # set flag for performance chart
      mri.chart[:miq] = {:performance => true}
      # this conditions are taken from build_performance_chart_area method from chart_commons.rb
      if mri.db.include?("Daily") || (mri.where_clause && mri.where_clause.include?("daily"))
        # set format for parsing
        mri.chart[:data][:xFormat] = '%m/%d'
        # set format for labels
        mri.chart[:axis][:x][:tick][:format] = '%m/%d'
      elsif mri.extras[:realtime] == true
        mri.chart[:data][:xFormat] = '%H:%M:%S'
        mri.chart[:axis][:x][:tick][:format] = '%H:%M:%S'
      else
        mri.chart[:data][:xFormat] = '%H:%M'
        mri.chart[:axis][:x][:tick][:format] = '%H:%M'
      end
    end
  end
end
