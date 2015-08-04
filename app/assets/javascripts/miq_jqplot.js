// MIQ specific jqplot related code

function _jqplot_eval_option(data, option) {
  var keys = option.split('.');
  var datum = data;
  try {
    $.each(keys, function (index, key) {
      if (index < keys.length - 1) {
        datum = datum[key];
      } else {
        datum[key] = eval(datum[key]);
      }
    });
  } catch (e) {}
}

function jqplot_process_options(data) {
  $.each([ 'seriesDefaults.renderer',
           'axes.xaxis.renderer',
           'axes.yaxis.tickRenderer',
           'axes.yaxis.renderer',
           'axes.xaxis.tickRenderer',
           'legend.renderer',
           'highlighter.tooltipContentEditor' ], function (index, key) {
    _jqplot_eval_option(data, key);
  });
  return data;
}

function load_jqplot_charts() {
  for (var set in ManageIQ.charts.chartData) {
    for (var i = 0; i < ManageIQ.charts.chartData[set].length; i++) {
      load_jqplot_chart(set, i);
    }
  }
}

function load_jqplot_chart(chart_set, index) {
  if (ManageIQ.charts.chartData[chart_set][index] == null) {
    return;
  }

  var chart_id = "miq_" + chart_set + "_" + index;
  var chart2_id = "miq_" + chart_set + "_" + index + "_2";
  var data = ManageIQ.charts.chartData[chart_set][index].xml;
  var data2 = ManageIQ.charts.chartData[chart_set][index].xml2;

  if ($('#' + chart_id).is(":visible")) {
    $.jqplot(chart_id, data.data, jqplot_process_options(data.options)).replot();
    if (typeof (data2) !== "undefined") {
      $.jqplot(chart2_id, data2.data, jqplot_process_options(data2.options)).replot();
    }
  }
}

function jqplot_register_chart(chart_id, chart) {
  ManageIQ.charts.charts[chart_id] = chart;
}

function jqplot_redraw_charts() {
  if (ManageIQ.charts.charts === null) {
    return;
  }
  for (var chart in ManageIQ.charts.charts)
    if (ManageIQ.charts.charts.hasOwnProperty(chart)) {
	    // We are passing in the foobar option to fool jqplot into doing full reInitialize()
	    // instead of quickInit() to properly recalculate the bar charts.
      try {
        ManageIQ.charts.charts[chart].replot({resetAxes: true, foobar: true});
      } catch (e) {};
    }
}

$(document).ready(function(){
  $(window).resize(function() {
    setTimeout(jqplot_redraw_charts, 500);
  });
});

