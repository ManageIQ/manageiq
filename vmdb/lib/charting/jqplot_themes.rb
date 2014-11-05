class JqplotThemes
  # for global css styles see http://www.jqplot.com/docs/files/jqPlotCssStyling-txt.html

  THEMES = {
    'MIQ' => { # name of 1st theme is hardcoded in UiConstants
      :seriesColors => ['#0099d3', '#00618a', '#0b3a54', '#979a9c', '#686b6e', '#505459', '#393f44', '#bde0ed'],
    }
  }

  def self.get_theme(theme_name)
    THEMES[theme_name]
  end
end
