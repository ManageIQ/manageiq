module ReportFormatter
  class ZgraphFormatter < Ruport::Formatter
    include ActionView::Helpers::UrlHelper
    include ChartCommon
    renders :zgraph, :for => ReportRenderer

    def initialize(*args)
      ZiyaCharting.init
      super
    end

    def series_class
      ZgraphSeries
    end

    def add_series(label, data)
      mri.chart.add(:series, label, data)
    end

    def add_axis_category_text(categories)
      mri.chart.add(:axis_category_text, categories)
    end

    def build_html_title
      mri.html_title = <<-EOD
      <div style='height: 10px;'></div>
      <ul id='tab'>"
        <li class='active'><a class='active'>#{mri.title}</a></li>
      </ul>
      <div class="clr"></div><div class="clr"></div><div class="b"><div class="b"><div class="b"></div></div></div>
      <div id="element-box"><div class="t"><div class="t"><div class="t"></div></div></div><div class="m">
      EOD
    end

    # create the graph object and add titles, fonts, and colors
    def build_document_header
      super
      graph_type = mri.graph.is_a?(Hash) ? mri.graph[:type] : mri.graph
      raise "Specified graph <#{graph_type}> is not a supported type" unless ZiyaCharting::CHARTS.include?(graph_type)

      build_html_title
      mri.chart = Ziya::Charts.const_get(graph_type).new(ZiyaCharting.xmlswf_license)
      ztheme = options.theme.nil? ? "miq" : options.theme.downcase
      mri.chart.add(:theme, ztheme)
      mri.chart.add(:user_data, :title, mri.title)
      mri.chart.add(:user_data, :show_title, options.show_title)
      mri.chart.add(:user_data, :graph_options, options.graph_options)
    end

    # write message into legend box and positions chart box off of the actual
    # graph box so it is hidden
    def no_records_found_chart(topic = "No records found for this chart")
      mri.chart.options[:graph_options].update(:chartx => 2000, :legendsize => 14)
      add_axis_category_text([''])
      add_series(topic, [{:value => 0}])
    end

    def finalize_document
      mri.chart = mri.chart.to_s
    end
  end
end
