module ReportFormatter
  class C3Formatter < Ruport::Formatter
    include ActionView::Helpers::UrlHelper
    include ChartCommon
    renders :c3, :for => ReportRenderer

    # series handling methods
    def series_class
      C3Series
    end

    def add_series(label, data)
      mri.chart[:data][:columns] << [ label, *data.map { |a| a[:value] } ]
      #mri.chart[:options][:series] << {:label => label}
    end

    def add_axis_category_text(categories)
      #mri.chart[:axis_category_text] << categories
    end

    # report building methods
    def build_document_header
      super
      mri.chart = {
#        :axis_category_text => [],
        :data => {
          :columns => [],
        },
#        :options            => {
#          :series => []
#        }
      }
    end

    def build_document_footer
#      mri.chart = Jqplot.apply_theme(mri.chart, options.theme) unless options.theme.nil?
    end

    def no_records_found_chart(topic = "No records found for this chart")
      mri.chart = {
        :data => {
          :columns => [],
        }
#        :options => {:title => topic}
      }
    end

    def finalize_document
#      mri.chart.delete(:axis_category_text)
#      mri.chart[:options][:title] ||= mri.title if options.show_title
      mri.chart
    end
  end
end
