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

      if chart_is_2d?
        mri.chart[:data][:columns] << [@counter, *data.map { |a| a[:value] }]
        mri.chart[:data][:names][@counter] = label
      else
        mri.chart[:data][:columns] = data.collect { |a| [a[:tooltip], a[:value]] }
      end

      if chart_is_stacked?
        mri.chart[:data][:groups][0] << @counter
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
        :data     => {:columns => []},
        :axis     => {}
      }

      if chart_is_2d?
        mri.chart[:data][:names] = {}
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
    end

    def c3_convert_type(type)
      CONVERT_TYPES[type] || type
    end

    def chart_is_2d?
      ['Bar', 'Column', 'StackedBar', 'StackedColumn', 'Line', 'Area', 'StackedArea'].include?(mri.graph[:type])
    end

    def chart_is_stacked?
      %w(StackedBar StackedColumn).include?(mri.graph[:type])
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
  end
end
