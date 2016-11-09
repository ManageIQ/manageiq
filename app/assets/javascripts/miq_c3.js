/* global chartData miqBuildChartMenuEx miqSparkleOff */

function load_c3_charts() {
  for (var set in ManageIQ.charts.chartData) {
    for (var i = 0; i < ManageIQ.charts.chartData[set].length; i++) {
      var chart_id = "miq_chart_" + set + "_" + i.toString();
      var data = ManageIQ.charts.chartData[set][i];
      if (data != null) {
        load_c3_chart(data.xml, chart_id);

        chart_id += "_2";
        if (typeof (data.xml2) !== "undefined") {
          data.xml2.miq.flat_chart = true;
          load_c3_chart(data.xml2, chart_id, 100);
        }
      }
    }
  }
  miqSparkleOff();
}

function load_c3_chart(data, chart_id, height) {
  if (typeof (data.miqChart) == "undefined") { data.miqChart = "Line"; }

  var generate_args = chartData(data.miqChart, data, { bindto: "#" + chart_id, size: {height: height}})

  generate_args.data.onclick = function (data, _i) {
    var seriesIndex = _.findIndex(generate_args.data.columns, function(col) { return col[0] == data.id; }) - 1
    var pointIndex = data.index;
    var value = data.value;

    var parts = chart_id.split('_'); // miq_chart_candu_2
    var chart_set   = parts[2];
    var chart_index = parts[3];

    miqBuildChartMenuEx(pointIndex, seriesIndex, value, data.name, data.id, chart_set, chart_index);

    // This is to allow the bootstrap pop-up to be manually fired from the chart's click event
    // and have it closed by clicking outside of the pop-up menu.
    setTimeout(function () {
      $(document).on('click.close_popup', function() {
        $('.chart_parent.open').removeClass('open').trigger(
          $.Event('hidden.bs.dropdown'), { relatedTarget: this });

        $('.chart_parent .overlay').hide();

        $(document).off('click.close_popup');
      });
    });

    return false;
  };
  var chart = c3.generate(generate_args);

  ManageIQ.charts.c3[chart_id] = chart;
};

c3.chart.internal.fn.categoryName = function (i) {
  var config = this.config, categoryIndex = Math.ceil(i);
  return i < config.axis_x_categories.length ? config.axis_x_categories[categoryIndex] : i;
};
