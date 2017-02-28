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


function recalculateChartYAxisLabels (id) {
  // hide/show chart with id
  this.api.toggle(id);

  var minMax = getMinMaxFromChart(this);

  if (minMax) {
    var columnsData = validateMinMax(minMax[0], minMax[1], minShowed, maxShowed);
    if (columnsData.invalid) {
      return;
    }
    minMax[0] = columnsData.min;
  } else {
    return;
  }

  var format = ManageIQ.charts.chartData.candu[this.config.bindto.split('_').pop()].xml.miq.format;
  var tmpMin = getChartFormatedValueWithFormat(format, minMax[0]);
  var tmpMax = getChartFormatedValueWithFormat(format, minMax[1]);
  var minShowed = tmpMin[0];
  var maxShowed = tmpMax[0];
  var min_units = tmpMin[1];
  var max_units = tmpMax[1];
  if (min_units !== max_units) {
    return;
  }

  var o = validatePrecision(minShowed, maxShowed, format, minMax[0], minMax[1]);
  if (o.changed) {
    this.config.axis_y_tick_format = o.format;
    this.api.flush();
  }
}

function validatePrecision(minShowed, maxShowed, format, min, max) {
  if (min === max) {
    return {'changed' : false, 'format' : ManageIQ.charts.formatters[format.function].c3(format.options)}
  }
  var recalculated = recalculatePrecision(minShowed, maxShowed, format, min, max);
  return {
    'changed' : recalculated.changed,
    'format'  : ManageIQ.charts.formatters[recalculated.format.function].c3(recalculated.format.options)
  }
}

function recalculatePrecision(minShowed, maxShowed, format, min, max) {
  var changed = false;
  if (maxShowed - minShowed <= Math.pow(10, 1 - format.options.precision)) {
    // if min and max are close, labels should be more precise
    changed = true;
    while (((maxShowed - minShowed ) * Math.pow(10, format.options.precision)) < 9.9) {
      format.options.precision += 1;
      minShowed = getChartFormatedValue(format, min);
      maxShowed = getChartFormatedValue(format, max);
    }
  } else if ((maxShowed - minShowed) >= Math.pow(10, 2 - format.options.precision)) {
    changed = true;
    // if min and max are not, labels should be less precise
    while (((maxShowed - minShowed ) * Math.pow(10, format.options.precision)) > 99) {
      if (format.options.precision < 1) {
        break;
      }
      format.options.precision -= 1;
      minShowed = getChartFormatedValue(format, min);
      maxShowed = getChartFormatedValue(format, max);
    }
  }
  return {'changed' : changed, 'format' : format};
}

function getMinMaxFromChart(chart) {
  var data = [];
  _.forEach(chart.api.data.shown(), function(o) {
    _.forEach(o.values, function(elem) {
      data.push(elem.value);
    });
  });

  var max = _.max(_.filter(data, function(o) { return o !== null; }));
  var min = _.min(_.filter(data, function(o) { return o !== null; }));
  if (max === -Infinity || min === Infinity) {
    return false;
  }
  return [min, max];
}

function getChartColumnDataValues(columns) {
  return _.filter(_.flatten(_.tail(columns).map(_.tail)), function(o) { return o !== null; })
}

function getChartFormatedValue(format, value) {
  return numeral(ManageIQ.charts.formatters[format.function].c3(format.options)(value).split(/[^0-9\,\.]/)[0]).value();
}

function getChartFormatedValueWithFormat(format, value) {
  var tmp = /^([0-9\,\.]+)(.*)/.exec(ManageIQ.charts.formatters[format.function].c3(format.options)(value));
  return [numeral(tmp[1]).value(), tmp[2]];
}

function validateMinMax(min, max, minShowed, maxShowed) {
  var invalid = false;
  // if there are no valid values or there is only single values big enough, then not change formating function
  if (max <= min || maxShowed < minShowed) {
    if (max < min || max > 10) {
      invalid = true;
    } else if (max > 0){
      min = 0;
    } else if (min === 0 && max === 0){
      invalid = true;
    }
  }

  return {'invalid' : invalid, 'min' : min };
}


c3.chart.internal.fn.categoryName = function (i) {
  var config = this.config, categoryIndex = Math.ceil(i);
  return i < config.axis_x_categories.length ? config.axis_x_categories[categoryIndex] : i;
};
