class JqplotThemes
  # for global css styles see http://www.jqplot.com/docs/files/jqPlotCssStyling-txt.html
  # for chart styling options see http://www.jqplot.com/docs/files/jqPlotOptions-txt.html

  THEMES = {
    # name of 1st theme is hardcoded in UiConstants
    'MIQ' => {
      :seriesColors   => ['#ec7a08', '#f4aa00', '#006e9c', '#0085cf', '#3f9c35', '#92D400', '#ccce00', '#ffff00', '#925bad', '#c0acdc', '#350000', '#a30000', '#cc0000',],
      :seriesDefaults => {
        :shadow          => false,
        :rendererOptions => {
          :dataLabelPositionFactor => 0.7,
          :sliceMargin             => 2
        }
      },
      :grid           => {
        :drawGridlines => true,     # mind the lowecase 'l'
        :gridLineColor => '#e1e1e1',
        :borderWidth => 0,
        :background => 'transparent',
        :shadow => false,
      },
      # use EnhancedLegendRenderer by default
      # http://www.jqplot.com/docs/files/plugins/jqplot-enhancedLegendRenderer-js.html
      :legend         => {
        :fontSize => '10px'
      }
    }
  }

  def self.get_theme(theme_name)
    THEMES[theme_name]
  end
end
