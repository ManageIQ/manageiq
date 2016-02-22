/**
 * C3 chart configuration for ManageIQ.
 *
 * To be replaced with `c3ChartDefaults` once available through PatternFly:
 *
 *   https://github.com/patternfly/patternfly/blob/master/dist/js/patternfly.js
 */

(function (ManageIQ) {

  var pfColors = ['#0088ce', '#00659c', '#3f9c35', '#ec7a08', '#cc0000', '#3b0083'];

  var c3mixins = {};

  c3mixins.showGrid = {
    grid: {
      x: {
        show: true
      },
      y: {
        show: true
      }
    }
  };

  c3mixins.smallerBarWidth = {
    bar: {
      width: {
        ratio: 0.3
      }
    }
  };

  c3mixins.noLegend = {
    legend: {
      show: false
    }
  };

  c3mixins.legendOnRightSide = {
    legend: {
      position: 'right'
    }
  };

  c3mixins.noTooltip = {
    tooltip: {
      show: false
    }
  };

  c3mixins.pfDataColorFunction = {
    data: {
      color: function (color, d) {
        return pfColors[d.index];
      }
    }
  };

  c3mixins.pfColorPattern = {
    color: {
      pattern: pfColors
    }
  };

  c3mixins.xAxisCategory = {
    axis: {
      x: {
        type: 'category',
        tick: {
          outer: false,
          multiline: false
        }
      }
    }
  };

  c3mixins.xAxisCategoryRotated = {
    axis: {
      x: {
        type: 'category',
        tick: {
          outer: false,
          multiline: false,
          rotate: 45
        }
      }
    }
  };

  c3mixins.yAxisNoOuterTick = {
    axis: {
      y: {
        tick: {
          outer: false
        }
      }
    }
  };

  function percentLabelFormat (value, ratio) {
    return d3.format('%')(ratio);
  }

  ManageIQ.charts.c3config = {

    Bar: _.defaultsDeep({
        data: {
          type: 'bar'
        },
        axis: {
          rotated: true
        }
      },
      c3mixins.xAxisCategory,
      c3mixins.yAxisNoOuterTick,
      c3mixins.pfDataColorFunction,
      c3mixins.showGrid,
      c3mixins.smallerBarWidth,
      c3mixins.noLegend,
      c3mixins.noTooltip
    ),

    Column: _.defaultsDeep({
        data: {
          type: 'bar'
        }
      },
      c3mixins.xAxisCategoryRotated,
      c3mixins.yAxisNoOuterTick,
      c3mixins.pfDataColorFunction,
      c3mixins.showGrid,
      c3mixins.smallerBarWidth,
      c3mixins.noLegend,
      c3mixins.noTooltip
    ),

    StackedBar: _.defaultsDeep({
        data: {
          type: 'bar'
        },
        axis: {
          rotated: true
        }
      },
      c3mixins.xAxisCategory,
      c3mixins.yAxisNoOuterTick,
      c3mixins.pfColorPattern,
      c3mixins.showGrid,
      c3mixins.smallerBarWidth,
      c3mixins.legendOnRightSide,
      c3mixins.noTooltip
    ),

    StackedColumn: _.defaultsDeep({
        data: {
          type: 'bar'
        }
      },
      c3mixins.xAxisCategoryRotated,
      c3mixins.yAxisNoOuterTick,
      c3mixins.pfColorPattern,
      c3mixins.showGrid,
      c3mixins.smallerBarWidth,
      c3mixins.legendOnRightSide,
      c3mixins.noTooltip
    ),

    Pie: _.defaultsDeep({
        data: {
          type: 'pie'
        },
        pie: {
          label: {
            format: percentLabelFormat
          },
          expand: false
        }
      },
      c3mixins.pfColorPattern,
      c3mixins.legendOnRightSide,
      c3mixins.noTooltip
    ),

    Donut: _.defaultsDeep({
        data: {
          type: 'donut'
        },
        donut: {
          label: {
            format: percentLabelFormat
          },
          expand: false
        }
      },
      c3mixins.pfColorPattern,
      c3mixins.legendOnRightSide,
      c3mixins.noTooltip
    )
  };
})(ManageIQ);
