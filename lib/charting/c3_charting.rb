class C3Charting < Charting
  # for Charting.detect_available_plugin
  def self.available?
    true
  end

  # for Charting.detect_available_plugin
  def self.priority
    10
  end

  # backend identifier
  def backend
    :c3
  end

  # format for rails' render
  def render_format
    :json
  end

  # formatter for Rupport::Controller#render - see lib/report_formatter/...
  def format
    # TODO - the actual formatter
    :c3
  end

  # called from each ApplicationController instance
  def load_helpers(klass)
    klass.instance_eval do
      # TODO
      helper C3Helper
    end
  end

  # validates (what?) data, called with..TODO?
  def data_ok?(data)
    p [ :data_ok?, data ]
    true
  end

  def sample_chart(options, report_theme)
    p [ :sample_chart, options, report_theme ]
    # TODO TODO
  end

  def js_load_statement(delayed = false)
    delayed ? 'setTimeout(function(){ load_jqplot_charts(); }, 100);' : 'load_jqplot_charts();'
  end

  # list of available chart types - in options_for_select format
  def chart_names_for_select
    CHART_NAMES
  end

  # list of themes - in options_for_select format
  def chart_themes_for_select
    ['Default', 'default']
  end

  private

  CHART_NAMES = [
    ["Bars (2D)",             "Bar"],
    ["Bars, Stacked (2D)",    "StackedBar"],
    ["Columns (2D)",          "Column"],
    ["Columns, Stacked (2D)", "StackedColumn"],
    ["Donut (2D)",            "Donut"],
    ["Pie (2D)",              "Pie"],
  ]

end
