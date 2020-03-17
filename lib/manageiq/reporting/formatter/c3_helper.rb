module ManageIQ
  module Reporting
    module Formatter
      module C3Helper
        def c3chart_remote(url, opts = {})
          chart_id = opts[:id] || ('chart' + rand(10**8).to_s)

          content_tag(:div, '', :id => chart_id) +
            javascript_tag(<<~EOJ)
              $.get("#{url}").success(function(data) {
                data.miq.zoomed = "#{opts[:zoomed]}";
                var chart = c3.generate(chartData(data.miqChart, data, { bindto: "##{chart_id}" }));
                ManageIQ.charts.c3["#{chart_id}"] = chart;
                miqSparkleOff();
              });
      EOJ
        end

        def c3chart_local(data, opts = {})
          chart_id = opts[:id] || ('chart' + rand(10**8).to_s)

          content_tag(:div, '', :id => chart_id) +
            javascript_tag(<<~EOJ)
              var data = #{data.to_json};
              var chart = c3.generate(chartData('#{data[:miqChart]}', data, { bindto: "##{chart_id}" }));
              ManageIQ.charts.c3["#{chart_id}"] = chart;
      EOJ
        end
      end
    end
  end
end
