// Note: when changing a formatter, please consider also changing the corresponding MiqReport::Formatting#format_* method

(function(window, moment, _) {
  "use strict";

  function apply_format_precision(val, precision) {
    if (val == null || ! _.isNumber(val))
      return val;
    return sprintf("%." + (~~ precision) + "f", val);
  };

  function apply_prefix_and_suffix(val, options) {
    options = options || {};
    return sprintf("%s%s%s", options.prefix || "", val, options.suffix || "");
  };

  function get_time_zone(default_tz) {
    // FIXME - like MiqReportGenerator#get_time_zone - time_profile.tz or .tz or the default
    return default_tz;
  };

  function number_with_delimiter(val, options) {
    options = _.extend({ delimiter: ',', separator: '.' }, options || {});
    var intpart, floatpart, minus;
    if (_.isNumber(val)) {
      intpart = ~~ val;
      floatpart = Math.abs(val - intpart);
      minus = val < 0;
      intpart = Math.abs(intpart);
    } else {
      minus = val[0] == '-';
      intpart = Math.abs(~~ val);
      floatpart = (val.indexOf('.') < 0) ? '' : val.replace(/^.*\./, '');
    }

    var s = "";
    while (intpart >= 1000) {
      s = options.delimiter + sprintf("%03d", intpart % 1000) + s;
      intpart = ~~( intpart / 1000 );
    }
    s = sprintf(minus ? "-%d" : "%d", intpart) + s;

    if (_.isNumber(floatpart) && floatpart > 1e-12) {
      s += options.separator;
      s += sprintf("%f", floatpart).replace(/^.*\./, '');
    } else if (_.isString(floatpart) && floatpart) {
      s += options.separator + floatpart;
    }

    return s;
  };

  function number_to_currency(val, options) {
    options = _.extend({
      precision: 2,
      unit: '$',
      delimiter: ',',
      separator: '.',
      format: '%u%n',
    }, options || {});

    if (! ('negative_format' in options)) {
      options.negative_format = '-' + options.format;
    }

    var numstr = val;
    if (_.isNumber(val)) {
      numstr = apply_format_precision(val, options.precision);
    }
    numstr = number_with_delimiter(numstr, options);

    var fmt = (numstr[0] == '-') ? options.negative_format : options.format;
    return fmt.replace('%u', options.unit).replace('%n', numstr);
  };

  function number_to_human_size(val, options) {
    var fmt = "0.0";
    if (options.precision < 1) {
      fmt = "0";
    } else {
      var p = options.precision - 1;
      while (p-- > 0) {
        fmt += '0';
      }
    }
    //console.log(val);
    //console.log(numeral(val).format(fmt));
    //var a = numeral(val).format(fmt).replace(/(?:\.0+|(\.\d+?)0+)$/, "$1");
    //return numeral(a).format(' b');
    return numeral(val).format(fmt + ' b');
  };

  function mhz_to_human_size(val, precision) {
    precision = _.isNumber(precision) ? precision : 1;
    precision = "%." + precision + "f";

    var s = val < 0 ? "-" : "";
    val = Math.abs(val);

    val *= 1000000; // mhz to hz
    if (val < 1000000000) {
      s += sprintf(precision + " MHz", val / 1000000);
    } else if (val < 1000000000000) {
      s += sprintf(precision + " GHz", val / 1000000000);
    } else {
      s += sprintf(precision + " THz", val / 1000000000000);
    }

    return s;
  };

  function ordinalize(val) {
    return numeral(val).format('0o');
  };

  function remove_right_side_zeros(str_val, separator) {
    var v = str_val.split(separator);
    return v[0].replace(/(?:\.0+|(\.\d+?)0+)$/, "$1") + separator + v[1];
  };

  var format = {
    number_with_delimiter: function(val, options) {
      options = options || {};
      var av_options = _.pick(options, [ 'delimiter', 'separator' ]);
      val = apply_format_precision(val, options.precision);
      val = number_with_delimiter(val, av_options);
      return apply_prefix_and_suffix(val, options);
    },

    currency_with_delimiter: function(val, options) {
      options = options || {};
      var av_options = _.pick(options, [ 'delimiter', 'separator' ]);
      val = apply_format_precision(val, options.precision);
      val = number_to_currency(val, av_options)
      return apply_prefix_and_suffix(val, options)
    },

    bytes_to_human_size: function(val, options) {
      options = options || {};
      var av_options = { precision: options.precision || 0 };  // Precision of 0 returns the significant digits
      val = number_to_human_size(val, av_options);
      return remove_right_side_zeros(apply_prefix_and_suffix(val, options), ' ');
    },

    kbytes_to_human_size: function(val, options) {
      return remove_right_side_zeros(format.bytes_to_human_size(val * 1024, options), ' ');
    },

    mbytes_to_human_size: function(val, options) {
      return remove_right_side_zeros(format.kbytes_to_human_size(val * 1024, options), ' ');
    },

    gbytes_to_human_size: function(val, options) {
      return remove_right_side_zeros(format.mbytes_to_human_size(val * 1024, options), ' ');
    },

    mhz_to_human_size: function(val, options) {
      options = options || {};
      val = mhz_to_human_size(val, options.precision);
      return apply_prefix_and_suffix(val, options);
    },

    boolean: function(val, options) {
      options = options || {};

      if (val !== true && val !== false)
        return _.capitalize( String(val) );

      switch (options.format) {
        case "yes_no":
          return val ? "Yes" : "No";

        case "y_n":
          return val ? "Y" : "N";

        case "t_f":
          return val ? "T" : "F";

        case "pass_fail":
          return val ? "Pass" : "Fail";

        default:
          return val ? "True" : "False";
      };
    },

    // note that we require moment-timezone so that %Z (which maps to moments z which uses zoneAbbr, which returns "UTC" or "" without moment-timezone) works
    datetime: function(val, options) {
      options = options || {};
      if (!moment.isDate(val) && !moment.isMoment(val))
        return val;

      val = moment(val);
      if (options.tz)
        val = val.tz(options.tz);

      if (! options.format)
        return val;

      return val.strftime(options.format);
    },

    datetime_range: function(val, options) {
      options = options || {};
      if (! options.format)
        return val;
      if (!moment.isDate(val) && !moment.isMoment(val))
        return val;

      val = moment(val);

      var col = options.column;
      var a = String(col).split("__");
      col = a[0];
      var sfx = a[1]; // The suffix (month, quarter, year) defines the range

      val = val.tz(get_time_zone("UTC"));
      var stime, etime;
      if (_.includes(['day', 'week', 'month', 'quarter', 'year'], sfx)) {
        stime = val.clone().startOf(sfx);
        etime = val.clone().endOf(sfx);
      } else {
        stime = val;
        etime = val;
      }

      // FIXME: added for compatibility with the ruby implementation, needs fixing on both sides
      if (_.includes(options.description || "", "Start"))
        return stime.strftime(options.format);
      else
        return "(" + stime.strftime(options.format) + " - " + etime.strftime(options.format) + ")";
    },

    set: function(val, options) {
      options = options || {};
      if (! _.isArray(val))
        return val;
      return val.join(options.delimiter || ", ");
    },

    datetime_ordinal: function(val, options) {
      options = options || {};
      val = format.datetime(val, options);
      return format.number_ordinal(val, options);
    },

    // used by datetime_ordinal
    number_ordinal: function(val, options) {
      options = options || {};
      return ordinalize(~~ val);
    },

    elapsed_time_human: function(val, options) {
      options = options || {};
      val = ~~ val;

      var names = [__('Day'), __('Hour'), __('Minute'), __('Second')];

      var days    = ~~(val / 86400);
      var hours   = ~~((val / 3600) - (days * 24));
      var minutes = ~~((val / 60) - (hours * 60) - (days * 1440));
      var seconds = ~~(val % 60);

      var arr = [days, hours, minutes, seconds];
      if (_.every(arr, 0))
        return "";

      var sidx = _.findIndex(arr, function(a) {
        return a > 0;
      });
      var values = _.slice(arr, sidx, sidx + 2);
      var result = '';
      var sep    = '';
      values.forEach(function(val, i) {
        var sfx = names[sidx + i];
        if (val > 1 || val == 0)
          sfx += "s";

        result += sep;
        result += values[i];
        result += " ";
        result += sfx;

        sep = ", ";
      });

      return result;
    },

    string_truncate: function(val, options) {
      options = options || {};
      var result = String(val);
      return (result.length > options.length) ? result.substr(0, options.length) + "..." : val;
    },

    large_number_to_exponential_form: function(val, options) {
      options = options || {};
      if (Number(val) < 1.0e+15)
        return val;
      return Number(val).toPrecision(2);
    },
  };

  // .foo(val, opt) or .foo.c3(opt)(val) or .foo.jqplot(opt)(_, val)
  window.ManageIQ.charts.formatters = _.mapValues(format, function(fn) {
    fn.c3 = _.curryRight(fn);

    fn.jqplot = function(opt) {
      return function(_fmt, val) {
        return fn(val, opt);
      };
    };

    return fn;
  });
})(window, moment, _);
