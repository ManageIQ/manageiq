// Note: when changing a formatter, please consider also changing the corresponding MiqReport::Formatting#format_* method
// TODO tests

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
      floatpart = val.replace(/^.*\./, '');
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
      numstr = number_with_delimiter(numstr, options);
    }

    var fmt = (numstr[0] == '-') ? options.negative_format : options.format;
    return fmt.replace('%u', options.unit).replace('%n', numstr);
  };

  function number_to_human_size(val, options) {
    var fmt = "0.0";
    if (options.precision < 2) {
      fmt = "0";
    } else {
      var p = options.precision - 2;
      while (p > 0) {
        fmt += '0';
      }
    }

    return numeral(val).format(fmt + ' b');
  };

  function mhz_to_human_size(val, precision) {
    precision = _.isNumber(precision) ? precision : 1;
    precision = "%." + precision + "f";

    var s = val < 0 ? "-" : "";
    val = Math.abs(val);

    val *= 1000000; // mhz to hz
    if (size < 1000000000) {
      s += sprintf(precision + " MHz", val / 1000000);
    } else if (size < 1000000000000) {
      s += sprintf(precision + " GHz", val / 1000000000);
    } else {
      s += sprintf(precision + " THz", val / 1000000000000);
    }

    return s;
  };

  function ordinalize(val) {
    return numeral(val).format('0o');
  };

  var format = {
    /*
      :description: Number (1,234)
      :function:
        :name: number_with_delimiter
        :delimiter: ","

      :description: Number (1,234.0)
      :function:
        :name: number_with_delimiter
        :delimiter: ","

      :description: Number, 2 Decimals (1,234.00)
      :function:
        :name: number_with_delimiter
        :delimiter: ","

      :description: Kilobytes per Second (10 KBps)
      :function: 
        :name: number_with_delimiter
        :delimiter: ","
        :suffix: " KBps"

      :description: Percentage (99%)
      :function: 
        :name: number_with_delimiter
        :delimiter: ","
        :suffix: ! '%'

      :description: Percent, 1 Decimal (99.0%)
      :function:
        :name: number_with_delimiter
        :delimiter: ","
        :suffix: ! '%'

      :description: Percent, 2 Decimals (99.00%)
      :function: 
        :name: number_with_delimiter
        :delimiter: ","
        :suffix: ! '%'
    */
    number_with_delimiter: function(val, options) {
      options = options || {};
      var av_options = _.pick(options, [ 'delimiter', 'separator' ]);
      val = apply_format_precision(val, options.precision);
      val = number_with_delimiter(val, av_options);
      return apply_prefix_and_suffix(val, options);
    },

    /*
      :description: Currency, 2 Decimals ($1,234.00)
      :function:
        :name: currency_with_delimiter
        :delimiter: ","
    */
    currency_with_delimiter: function(val, options) {
      options = options || {};
      var av_options = _.pick(options, [ 'delimiter', 'separator' ]);
      val = apply_format_precision(val, options.precision);
      val = number_to_currency(val, av_options)
      return apply_prefix_and_suffix(val, options)
    },

    /*
      :description: Suffixed Bytes (B, KB, MB, GB)
      :function:
        :name: bytes_to_human_size
    */
    bytes_to_human_size: function(val, options) {
      options = options || {};
      var av_options = { precision: options.precision || 0 };  // Precision of 0 returns the significant digits
      val = number_to_human_size(val, av_options);
      return apply_prefix_and_suffix(val, options);
    },

    /*
      :description: Suffixed Kilobytes (KB, MB, GB)
      :function:
        :name: kbytes_to_human_size
    */
    kbytes_to_human_size: function(val, options) {
      return format.bytes_to_human_size(val * 1024, options);
    },

    /*
      :description: Suffixed Megabytes (MB, GB)
      :function:
        :name: mbytes_to_human_size
    */
    mbytes_to_human_size: function(val, options) {
      return format.kbytes_to_human_size(val * 1024, options);
    },

    /*
      :description: Suffixed Gigabytes (GB)
      :function:
        :name: gbytes_to_human_size
    */
    gbytes_to_human_size: function(val, options) {
      return format.mbytes_to_human_size(val * 1024, options);
    },

    /*
      :description: Megahertz (12 Mhz)
      :function: 
        :name: mhz_to_human_size
        :delimiter: ","

      :description: Megahertz Avg (12.1 Mhz)
      :function:
        :name: mhz_to_human_size
        :delimiter: ","
    */
    mhz_to_human_size: function(val, options) {
      options = options || {};
      val = mhz_to_human_size(val, options.precision);
      return apply_prefix_and_suffix(val, options);
    },

    /*
      :description: Boolean (True/False)
      :function:
        :name: boolean

      :description: Boolean (T/F)
      :function:
        :name: boolean
        :format: t_f

      :description: Boolean (Yes/No)
      :function:
        :name: boolean
        :format: yes_no

      :description: Boolean (Y/N)
      :function:
        :name: boolean
        :format: y_n

      :description: Boolean (Pass/Fail)
      :function:
        :name: boolean
        :format: pass_fail
    */
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

    /*
      :description: Date (M/D/YYYY)
      :function:
        :name: datetime
        :format: "%m/%d/%Y"

      :description: Date (M/D/YY)
      :function:
        :name: datetime
        :format: "%m/%d/%y"

      :description: Date (M/D)
      :function:
        :name: datetime
        :format: "%m/%d"

      :description: Time (H:M:S Z) 
      :function:
        :name: datetime
        :format: "%H:%M %Z"

      :description: Date/Time (M/D/Y H:M:S Z)
      :function:
        :name: datetime
        :format: "%m/%d/%y %H:%M:%S %Z"

      :description: Date/Hour (M/D/Y H:00 Z)
      :function:
        :name: datetime
        :format: "%m/%d/%y %H:00 %Z"

      :description: Date/Hour (M/D/Y H AM|PM Z)
      :function:
        :name: datetime
        :format: "%m/%d/%y %I %p %Z"

      :description: Hour (H:00 Z)
      :function:
        :name: datetime
        :format: "%H:00 %Z"

      :description: Hour (H AM|PM Z)
      :function:
        :name: datetime
        :format: "%l %p %Z"

      :description: Hour of Day (24)
      :function:
        :name: datetime
        :format: "%k"

      :description: Day Full (Monday)
      :function:
        :name: datetime
        :format: "%A"

      :description: Day Short (Mon)
      :function:
        :name: datetime
        :format: "%a"

      :description: Day of Week (1)
      :function:
        :name: datetime
        :format: "%u"

      :description: Day of Month (27)
      :function:
        :name: datetime
        :format: "%e"

      :description: Month and Year (January 2011)
      :function:
        :name: datetime
        :format: "%B %Y"

      :description: Month and Year Short (Jan 11)
      :function:
        :name: datetime
        :format: "%b %y"

      :description: Month Full (January)
      :function:
        :name: datetime
        :format: "%B"

      :description: Month Short (Jan)
      :function:
        :name: datetime
        :format: "%b"

      :description: Month of Year (12)
      :function:
        :name: datetime
        :format: "%m"

      :description: Week of Year (52)
      :function:
        :name: datetime
        :format: "%W"

      :description: Year (YYYY)
      :function:
        :name: datetime
        :format: "%Y"
    */
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

    /*
      :description: Date Range (M/D/Y - M/D/Y)
      :function:
        :name: datetime_range
        :format: "%m/%d/%y"

      :description: Day Range (M/D - M/D)
      :function:
        :name: datetime_range
        :format: "%m/%d"

      :description: Day Range Start (M/D)
      :function:
        :name: datetime_range
        :format: "%m/%d"
    */
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

    /*
      :description: Comma seperated list
      :function:
        :name: set
        :delimiter: ", "
    */
    set: function(val, options) {
      options = options || {};
      if (! _.isArray(val))
        return val;
      return val.join(options.delimiter || ", ");
    },

    /*
      :description: Day of Month (27th)
      :function:
        :name: datetime_ordinal
        :format: "%e"

      :description: Week of Year (52nd)
      :function:
        :name: datetime_ordinal
        :format: "%W"
    */
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

    /*
      :description: "Elapsed Time (10 Days, 0 Hours, 1 Minute, 44 Seconds)"
      :function:
        :name: elapsed_time_human
    */
    elapsed_time_human: function(val, options) {
      options = options || {};
      val = ~~ val;

      var names = ['day', 'hour', 'minute', 'second'];

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
      var values = _.slice(arr, sidx, sidx + 1);
      var result = '';
      var sep    = '';
      for (var i in values) {
        var sfx = names[sidx + i];
        if (values[i] > 1 || values[i] == 0)
          sfx += "s";

        result += sep;
        result += values[i];
        result += " ";
        result += sfx;

        sep = ", ";
      }

      return result;
    },

    /*
      :description: String Truncated to 50 Characters with Elipses (...)
      :function:
        :name: string_truncate
        :length: 50
    */
    string_truncate: function(val, options) {
      options = options || {};
      var result = String(val);
      return (result.length > options.length) ? result.substr(0, options.length) + "..." : val;
    },

    /*
      :description: Convert Numbers Larger than 1.0e+15 to Exponential Form
      :function:
        :name: large_number_to_exponential_form
        :length: 50
    */
    large_number_to_exponential_form: function(val, options) {
      options = options || {};
      if (Number(val) < 1.0e+15)
        return val;
      return String( Number(val) );
    },
  };

  // curryRight so that formatters.foo(options) returns a function(val)->string
  window.ManageIQ.charts.formatters = _.mapValues(format, _.curryRight);
})(window, moment, _);
