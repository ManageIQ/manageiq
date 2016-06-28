/**
 * C3 chart configuration for ManageIQ.
 *
 * To be replaced with `c3ChartDefaults` once available through PatternFly:
 *
 *   https://github.com/patternfly/patternfly/blob/master/dist/js/patternfly.js
 */

(function (ManageIQ) {

  var pfColors = [$.pfPaletteColors.blue, $.pfPaletteColors.red, $.pfPaletteColors.green, $.pfPaletteColors.orange, $.pfPaletteColors.cyan,
    $.pfPaletteColors.gold, $.pfPaletteColors.purple, $.pfPaletteColors.lightBlue, $.pfPaletteColors.lightGreen, $.pfPaletteColors.black];
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
      color: function (_color, d) {
        return pfColors[d.index % pfColors.length];
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


  ManageIQ.charts.c3config = {

    Bar: _.defaultsDeep(
      {
        axis : {x:{type: 'category'},
                       rotated: true},
        data : {type: 'bar'},
        tooltip: {grouped: false},
        legend: { show: true, position: 'right'}
      },
      c3mixins.pfColorPattern,
      $().c3ChartDefaults().getDefaultBarConfig()
    ),

    Column: _.defaultsDeep(
      {
        axis : {x:{type: 'category'}},
        data : {type: 'bar'},
        tooltip: {grouped: false},
        legend: { show: true, position: 'right'}
      },c3mixins.pfColorPattern,
      $().c3ChartDefaults().getDefaultBarConfig()

    ),

    StackedBar: _.defaultsDeep(
      {
        axis : {x:{type: 'category'},
                       rotated: true},
        data : {type: 'bar'},
      },c3mixins.pfColorPattern,
      $().c3ChartDefaults().getDefaultGroupedBarConfig()
    ),

    StackedColumn: _.defaultsDeep(
      {
        axis : {x:{type: 'category'}},
        data : {type: 'bar'},
      },c3mixins.pfColorPattern,
      $().c3ChartDefaults().getDefaultGroupedBarConfig()
    ),

    Pie: _.defaultsDeep(
      {
        data: {type: 'pie'},
        tooltip: {show: true},
        legend: { show: true, position: 'right'}
      },c3mixins.pfColorPattern,
      $().c3ChartDefaults().getDefaultDonutConfig()
    ),

  Donut: _.defaultsDeep(
      {
        data: {type: 'donut'},
        tooltip: {show: true},
        legend: { show: true, position: 'right'}
      },c3mixins.pfColorPattern,
      $().c3ChartDefaults().getDefaultDonutConfig()
    ),

    Line: _.defaultsDeep(
      {
        axis : {x:{type: 'category'}},
        data : {type: 'line'},
      },c3mixins.pfColorPattern,
      $().c3ChartDefaults().getDefaultLineConfig()
    ),
    Area: _.defaultsDeep(
      {
        axis : {x:{type: 'category'}},
        data : {type: 'area'},
      },c3mixins.pfColorPattern,
      $().c3ChartDefaults().getDefaultAreaConfig()
    ),
    StackedArea: _.defaultsDeep(
     {
       axis : {x:{type: 'category'}},
       data : {type: 'area'},
     },c3mixins.pfColorPattern,
     $().c3ChartDefaults().getDefaultAreaConfig()
   ),
  };
})(ManageIQ);
