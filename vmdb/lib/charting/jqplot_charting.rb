class JqplotCharting < Charting
  def js_load_statement(delayed = false)
    delayed ? 'setTimeout(function(){ load_jqplot_charts(); }, 100);' : 'load_jqplot_charts();'
  end

  def render_format
    :json
  end

  def format
    :jqplot
  end

  def backend
    :jqplot
  end

  def load_helpers(klass)
    klass.instance_eval do
      helper JqplotHelper
    end
  end

  def data_ok?(data)
    !!YAML.load(data)
  rescue Psych::SyntaxError
    false
  end

  def sample_chart(options, report_theme)
    add_sample_chart_data(options, sample_chart_options(options, report_theme))
  end

  def self.priority
    1
  end

  def chart_names_for_select
    CHART_NAMES
  end

  CHART_NAMES = [
    ["Bars (2D)",             "Bar"],
    ["Bars, Stacked (2D)",    "StackedBar"],
    ["Columns (2D)",          "Column"],
    ["Columns, Stacked (2D)", "StackedColumn"],
    ["Pie (2D)",              "Pie"],
    ["Donut (2D)",            "Donut"],
  ]

  def chart_themes_for_select
    JqplotThemes::THEMES.collect { |name, _| [name, name] }
  end

  private

  def add_sample_chart_data(options, chart)
    graph_count = options[:graph_count].to_i

    case options[:graph_type]
    when 'Pie', 'Donut'
      series = graph_count.times.each_with_object([]) do |i, acc|
        acc.push([i.ordinalize + " Operating System", graph_count + 2 - i])
      end
      series.push(['Other', rand(options[:graph_count].to_i) + 1]) if options[:graph_other]
      chart[:data] = [series]
    when 'Bar', 'StackedBar', 'Column', 'StackedColumn'
      graph_count.times do |i|
        chart[:options][:series] << {:label => "#{i.ordinalize} Operating System"}
        chart[:data] << 4.times.collect { (rand(5) + 1) * (graph_count + 1 - i) }
      end
      if options[:graph_other]
        chart[:options][:series] << {:label => 'Other'}
        chart[:data] << 4.times.collect { rand(10) }
      end
    end
    chart
  end

  def sample_chart_options(options, report_theme)
    chart = Jqplot.basic_chart(options[:graph_type])
    chart = Jqplot.horizontal_legend(
      Jqplot.horizontal_line_cursor(chart)) unless %w(Pie Donut).include?(options[:graph_type])
    Jqplot.apply_theme(chart, report_theme)
  end

  def self.available?
    true
  end
end
