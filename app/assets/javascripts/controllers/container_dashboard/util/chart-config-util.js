var chartConfig = {
  cpuUsageConfig: {
    chartId: 'cpuUsageChart',
    title: 'CPU',
    units: 'Cores',
    usageDataName: 'Used',
    legendLeftText: 'Last 30 Days',
    legendRightText: '',
    tooltipType: 'valuePerDay',
    numDays: 30,
    sparklineChartHeight: 60
  },
  memoryUsageConfig: {
    chartId: 'memoryUsageChart',
    title: 'Memory',
    units: 'GB',
    usageDataName: 'Used',
    legendLeftText: 'Last 30 Days',
    legendRightText: '',
    tooltipType: 'valuePerDay',
    numDays: 30,
    sparklineChartHeight: 60
  }
};
