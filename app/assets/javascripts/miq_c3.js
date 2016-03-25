function load_c3_charts() {
  for (var set in ManageIQ.charts.chartData) {
    for (var i = 0; i < ManageIQ.charts.chartData[set].length; i++) {
      var chart_id = "miq_chart_candu_" + i.toString();
      var data = ManageIQ.charts.chartData[set][i];
      load_c3_chart(data.xml, chart_id);

      chart_id += "_2";
      if (typeof (data.xml2) !== "undefined") {load_c3_chart(data.xml2, chart_id, 100);}
    }
  }
  miqSparkleOff();
}
function load_c3_chart(data, chart_id, height) {
  if (typeof (data.miqChart) == "undefined") {data.miqChart = "Line";}
  var chart = c3.generate(chartData(data.miqChart, data, { bindto: "#" + chart_id, size: {height: height}}));
  ManageIQ.charts.c3[chart_id] = chart;
}
