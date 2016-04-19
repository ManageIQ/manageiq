function load_c3_charts() {
  for (var set in ManageIQ.charts.chartData) {
    for (var i = 0; i < ManageIQ.charts.chartData[set].length; i++) {
      var chart_id = "miq_chart_candu_" + i.toString();
      var data = ManageIQ.charts.chartData[set][i];
      if(data != null){
        load_c3_chart(data.xml, chart_id);


        chart_id += "_2";
        if (typeof (data.xml2) !== "undefined") {
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

  generate_args.data.onclick = function (data, i) {
    var seriesIndex = data.id;
    var pointIndex = data.x;

    var parts = chart_id.split('_'); //miq_chart_candu_2
    var chart_set   = parts[2];
    var chart_index = parts[3];

    var col = row = category = 0; // fixme

    miqBuildChartMenuEx(seriesIndex, pointIndex, null, 'CAT', 'SER', chart_set, chart_index);

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
}
