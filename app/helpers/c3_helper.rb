module C3Helper
  def c3chart_sample
    content_tag(:div, '', :id => 'chart') +
    javascript_tag(<<-EOJ)
c3.generate({
  bindto: '#chart',
  data: {
    columns: [
      ['data1', 30, 200, 100, 400, 150, 250],
      ['data2', 50, 20, 10, 40, 15, 25]
    ]
  }
});
EOJ
  end

  def c3chart_remote(url, opts = {})
    chart_id = opts[:id] || ('chart' + rand(10**8).to_s)

    content_tag(:div, '', :id => chart_id) +
    javascript_tag(<<-EOJ)
$.get("#{url}").success(function(data) {
  var config = ManageIQ.charts.c3config[data.miqChart];
  var chart = c3.generate(_.defaultsDeep(config, data, { bindto: "##{chart_id}" }));
  ManageIQ.charts.c3["#{chart_id}"] = chart;
});
EOJ
  end

  def c3chart_local(data, opts = {})
    chart_id = opts[:id] || ('chart' + rand(10**8).to_s)

    content_tag(:div, '', :id => chart_id) +
    javascript_tag(<<-EOJ)
var data = #{data.to_json};
var config = ManageIQ.charts.c3config['#{data[:miqChart]}'];
var chart = c3.generate(_.defaultsDeep(config, data, { bindto: "##{chart_id}" }));
ManageIQ.charts.c3["#{chart_id}"] = chart;
EOJ
  end
end
