class JqplotThemes
  # for global css styles see http://www.jqplot.com/docs/files/jqPlotCssStyling-txt.html
  # for chart styling options see http://www.jqplot.com/docs/files/jqPlotOptions-txt.html

  THEMES = {
    # name of 1st theme is hardcoded in UiConstants
    'MIQ' => {
      :seriesColors   => ['#0099d3', '#00618a', '#0b3a54', '#979a9c', '#686b6e', '#505459', '#393f44', '#bde0ed'],
      :seriesDefaults => {
        :shadow => false
      },
      :grid           => {
        :drawGridlines => true,     # mind the lowecase 'l'
        :gridLineColor => '#e1e1e1',
        :borderWidth => 0,
        :background => 'transparent',
        :shadow => false
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
