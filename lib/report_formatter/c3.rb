module ReportFormatter
  class C3Formatter < Ruport::Formatter
    include ActionView::Helpers::UrlHelper
    include ChartCommon
    renders :c3, :for => ReportRenderer

    CONVERT_TYPES = {
      "ColumnThreed"         => "Column",
      "ParallelThreedColumn" => "Column",
      "StackedThreedColumn"  => "StackedColumn",
      "PieThreed"            => "Pie"
    }
    # series handling methods
    def series_class
      C3Series
    end

    def add_series(label, data)
      @counter ||= 0
      @counter += 1
      series_id = label + '_' + @counter.to_s

      if chart_is_2d?
        mri.chart[:data][:columns] << [series_id, *data.map { |a| a[:value] }]
        mri.chart[:data][:names][series_id] = label
      else
        mri.chart[:data][:columns] = data.collect { |a| [a[:tooltip], a[:value]] }
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
        :data     => {:columns => []}
      }

      if chart_is_2d?
        mri.chart[:data][:names] = {}
        mri.chart[:axis] = {
          :x => {
            :categories => []
          }
        }
      end

      if chart_is_stacked?
        mri.chart[:data][:groups] = [[]]
      end
    end

    def c3_convert_type(type)
      CONVERT_TYPES[type] || type
    end

    def chart_is_2d?
      %w(Bar Column StackedBar StackedColumn).include?(mri.graph[:type])
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
