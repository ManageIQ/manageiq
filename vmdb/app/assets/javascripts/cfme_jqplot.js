// MIQ specific jqplot related code

function _jqplot_eval_option(data, option) {
  var keys  = option.split('.');
  var datum = data;
  try {
    $j.each(keys, function (index, key) {
      if (index < keys.length-1)
        datum = datum[key];
      else
        datum[key] = eval(datum[key]);
    });
  } catch (e) {}
}

function jqplot_process_options(data) {
  $j.each(['seriesDefaults.renderer',
           'axes.xaxis.renderer',
           'legend.renderer',
           'highlighter.tooltipContentEditor'], function (index, key) {
    _jqplot_eval_option(data, key);
  });
  return data;
}

function load_jqplot_charts() {
  for (var set in miq_chart_data) {
    for (var i = 0; i < miq_chart_data[set].length; i = i + 1)
      load_jqplot_chart(set, i);
  }
}

function load_jqplot_chart(chart_set, index) {
  var chart_id  = "miq_" + chart_set + "_" + index;
  var chart2_id = "miq_" + chart_set + "_" + index + "_2";
  var data  = miq_chart_data[chart_set][index].xml;
  var data2 = miq_chart_data[chart_set][index].xml2;

  if ($j('#'+chart_id).is(":visible")) {
    $j.jqplot(chart_id, data.data, jqplot_process_options(data.options)).replot();
    if (typeof(data2) !== "undefined")
      $j.jqplot(chart2_id, data2.data, jqplot_process_options(data2.options)).replot();
  }
}

