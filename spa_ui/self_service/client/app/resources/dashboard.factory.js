(function() {
  'use strict';

  angular.module('app.resources')
    .factory('Dashboard', DashboardFactory);

  /** @ngInject */
  function DashboardFactory() {
    return [{
      options: {
        chart: {
          type: 'spline'
        },
        credits: {
          enabled: false
        },
        title: {
          text: 'Hourly Burn Analysis'
        },
        subtitle: {
          text: 'A snapshot of the last 24 hours.'
        },
        xAxis: {
          type: 'datetime',
          labels: {
            overflow: 'justify'
          }
        },
        yAxis: {
          title: {
            text: '% Budget Utilization'
          },
          min: 0,
          minorGridLineWidth: 0,
          gridLineWidth: 0,
          alternateGridColor: null,
          plotBands: [{
            from: 0,
            to: 30,
            color: 'rgba(0, 255, 255, 0.3)',
            label: {
              text: 'Low Burn',
              style: {
                color: '#000000'
              }
            }
          }, {
            from: 30,
            to: 60,
            color: 'rgba(29, 197, 142, 0.3)',
            label: {
              text: 'Normal Burn',
              style: {
                color: '#000000'
              }
            }
          }, {
            from: 60,
            to: 90,
            color: 'rgba(255, 255, 0, 0.3)',
            label: {
              text: 'Medium Burn',
              style: {
                color: '#000000'
              }
            }
          }, {
            from: 90,
            to: 100,
            color: 'rgba(248, 137, 84, 0.6)',
            label: {
              text: 'High Burn',
              style: {
                color: '#000000'
              }
            }
          }, {
            from: 100,
            to: 150,
            color: 'rgba(241, 59, 84, 0.3)',
            label: {
              text: 'Unsustainable Burn',
              style: {
                color: '#000000'
              }
            }
          }]
        },
        tooltip: {
          valueSuffix: ' %'
        },
        plotOptions: {
          spline: {
            lineWidth: 2,
            states: {
              hover: {
                lineWidth: 4
              }
            },
            marker: {
              enabled: false
            },
            pointInterval: 3600000, // one hour
            pointStart: Date.UTC(2015, 5, 18, 0, 0, 0)
          }
        }
      },
      series: [{
        name: 'Project Jellyfish',
        data: [40.3, 50.1, 40.3, 50.2, 50.4, 40.7, 30.5, 40.1, 50.6, 70.4, 60.9, 70.1,
          70.9, 70.9, 70.5, 60.7, 70.7, 70.7, 70.4, 70.0, 70.1, 50.8, 50.9, 70.4, 80.1],
        color: '#F88954'

      }, {
        name: 'Cloud Exchange',
        data: [0.0, 0.0, 20.0, 119, 45.0, 58.0, 68.0, 11.0, 2.1, 0.0, 0.3, 0.0,
          0.0, 0.4, 0.0, 10.1, 0.0, 0.0, 0.0, 0.0, 0.0, 90.0, 100.0, 0.0, 20.2],
        color: '#1DC58E'
      },
        {
          name: 'Blog',
          data: [10.0, 30.0, 0.0, 2, 5, 0.0, 3, 2, 5, 1, 0.3, 0.0,
            0.0, 0.4, 0.0, 20.1, 0.0, 0.0, 80.0, 0.0, 10.0, 30.0, 20.0, 120.0, 110],
          color: '#3397DB'
        }],
      navigation: {
        menuItemStyle: {
          fontSize: '10px'
        }
      }
    },
      {
        options: {
          chart: {
            type: 'column'
          },
          title: {
            text: 'Monthly Cost Analysis'
          },
          xAxis: {
            categories: [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec'
            ],
            crosshair: true
          },
          yAxis: {
            lineWidth: 1,
            tickWidth: 1,
            title: {
              align: 'high',
              offset: 0,
              text: 'Cost ($1000 USD)',
              rotation: 0,
              y: -10
            }
          },
          tooltip: {
            headerFormat: '<span style="font-size:10px">{point.key}</span><table>',
            pointFormat: '<tr><td style="color:{series.color};padding:0">{series.name}: </td>' +
            '<td style="padding:0"><b>{point.y:.1f}</b></td></tr>',
            footerFormat: '</table>',
            shared: true,
            useHTML: true
          },
          plotOptions: {
            column: {
              pointPadding: 0.2,
              borderWidth: 0
            }
          },
          credits: {
            enabled: false
          }
        },
        series: [{
          name: 'Project Jellyfish',
          data: [49.9, 71.5, 106.4, 129.2, 144.0, 176.0, 135.6, 148.5, 216.4, 194.1, 95.6, 54.4],
          color: '#F88954'

        }, {
          name: 'Blog',
          data: [83.6, 78.8, 98.5, 93.4, 106.0, 84.5, 105.0, 104.3, 91.2, 83.5, 106.6, 92.3]

        }, {
          name: 'Cloud Exchange',
          data: [48.9, 38.8, 39.3, 41.4, 47.0, 48.3, 59.0, 59.6, 52.4, 65.2, 59.3, 51.2],
          color: '#1DC58E'

        }]
      },
      {
        chart: {
          plotBackgroundColor: null,
          plotBorderWidth: null,
          plotShadow: false
        },
        title: {
          text: 'Active Service Types by Overall % '
        },
        tooltip: {
          pointFormat: '{series.name}: <b>{point.percentage:.1f}%</b>'
        },
        plotOptions: {
          pie: {
            allowPointSelect: true,
            cursor: 'pointer',
            dataLabels: {
              enabled: true,
              format: '<b>{point.name}</b>: {point.percentage:.1f} %',
              style: {
                color: 'black'
              }
            }
          }
        },
        series: [{
          type: 'pie',
          name: 'Active Service Percentages',
          data: [
            ['MS Exchange Server', 45.0],
            ['Rails Stack', 26.8],
            {
              name: 'LampStack',
              y: 12.8,
              sliced: true,
              selected: true
            },
            ['Small MySQL', 8.5],
            ['S3 Storage', 6.2],
            ['Large PostgreSQL', 0.7]
          ]
        }]
      },
      {
        options: {
          chart: {
            type: 'column',
            options3d: {
              enabled: true,
              alpha: 15,
              beta: 15,
              viewDistance: 25,
              depth: 40
            },
            marginTop: 80,
            marginRight: 40
          },

          title: {
            text: 'Total Services by Project'
          },

          xAxis: {
            categories: ['Blog', 'Project Jellyfish', 'Cloud Exchange']
          },

          yAxis: {
            allowDecimals: false,
            min: 0,
            title: {
              text: 'Number of Services'
            }
          },

          tooltip: {
            headerFormat: '<b>{point.key}</b><br>',
            pointFormat: '<span style="color:{series.color}">\u25CF</span> ' +
            '{series.name}: {point.y} / {point.stackTotal}'
          },

          plotOptions: {
            column: {
              stacking: 'normal',
              depth: 40
            }
          }
        },

        series: [{
          name: 'MS Exchange Server',
          data: [4, 4, 2]
        }, {
          name: 'Rails Stack',
          data: [3, 2, 4]
        }, {
          name: 'LampStack',
          data: [3, 0, 1]
        }, {
          name: 'Small MySQL',
          data: [1, 1, 1]
        }, {
          name: 'S3 Storage',
          data: [2, 0, 1]
        }, {
          name: 'Large PostgreSQL',
          data: [1, 0, 0]
        }]
      }
    ];
  }
})();
