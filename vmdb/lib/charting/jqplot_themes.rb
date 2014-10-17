class JqplotThemes
  # for global css styles see http://www.jqplot.com/docs/files/jqPlotCssStyling-txt.html

  THEMES = {
    'theme1' => {
      :seriesColors => ['#85802b', '#00749F', '#73C774', '#C7754C', '#17BDB8'],
    }
  }

  def self.get_theme(theme_name)
    THEMES[theme_name]
  end
end
