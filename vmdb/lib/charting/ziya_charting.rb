class ZiyaCharting < Charting
  def self.config
    @config ||= begin
      yml = Rails.root.join("config/ziya_charting.yml")
      File.exists?(yml) ? YAML.load_file(yml) : {}
    end
  end

  def self.xmlswf_license
    config["license"]
  end

  def self.extra_themes
    config["extra_themes"] || []
  end

  def self.init
    return @initialized if defined?(@initialized)

    require 'ziya'
    unless Ziya.const_defined?(:Version)
      # TODO: Ziya should really require builder since it depends on it!
      require 'builder'
      Ziya.initialize(
        :logger     => Rails.logger,
        :themes_dir => File.join(Rails.root, %w{public charts themes})
      )
    end
    @initialized = true
  end

  ZTHEMES = %w{Commando Pastel Primary} + extra_themes
  CHARTS  = %w{Area AreaThreed Bar CandleStick Column ColumnThreed Line ParallelThreedColumn
  Pie PieThreed StackedArea StackedBar StackedColumn StackedThreedArea StackedThreedColumn}

  def js_load_statement(_delayed = false)
    # FIXME: only for IE
    'miqLoadCharts();'
  end

  def render_format
    :xml
  end

  def format
    :zgraph
  end

  def backend
    :ziya
  end

  def load_helpers(klass)
    self.class.init
    klass.instance_eval do
      helper Ziya::HtmlHelpers::Charts
      helper Ziya::YamlHelpers::Charts
    end
  end

  def data_ok?(data)
    data.strip =~ /\A<\?xml/ rescue false
  end

  def sample_chart(options, report_theme)
    graph_count = options[:graph_count].to_i

    zgraph = Ziya::Charts.const_get(options[:graph_type]).new(self.class.xmlswf_license)
    zgraph.add(:theme, report_theme.downcase)
    zgraph.add(:user_data, :graph_options, MiqReport.graph_options(400, 250))

    if options[:graph_type] =~ /^Pie/  # Pie charts must be set to 1 dimension
      # Gen text labels for legend
      cat_text = graph_count.times.each_with_object([]) { |i, acc| acc.push(i.ordinalize + " Operating System") }
      cat_text.push("Other") if options[:graph_other]            # Add "Other" legend label
      zgraph.add(:axis_category_text, cat_text)                  # Add the category texts to the chart
      # Gen random values, high to low
      series = graph_count.times.each_with_object([]) { |i, acc| acc.push(graph_count + 2 - i) }
      series.push(rand(options[:graph_count].to_i) + 1) if options[:graph_other] # Add a final value for "other"
      zgraph.add(:series, "OS", series)                          # Add the series values to the chart
    else
      zgraph.add(:axis_category_text, ["Vendor A", "Vendor B", "Vendor C", "Vendor D"])
      # Build the series for each OS
      graph_count.times do |i|
        zgraph.add(:series, "#{i.ordinalize} Operating System",
                   4.times.collect { (rand(5) + 1) * (graph_count + 1 - i) })
      end
      zgraph.add(:series, "Other", 4.times.collect { rand(10) }) if options[:graph_other]
    end

    zgraph.to_s
  end

  def chart_names_for_select
    CHART_NAMES
  end

  CHART_NAMES = [
    # ["Area",                 "Area"],
    # ["Area, Stacked",        "StackedArea"],
    ["Bars (2D)",              "Bar"],
    ["Bars, Stacked (2D)",     "StackedBar"],
    # ["Candlestick",            "CandleStick"],
    ["Columns (2D)",           "Column"],
    ["Columns, Stacked (2D)",  "StackedColumn"],
    ["Columns (3D)",           "ColumnThreed"],
    ["Columns, Parallel (3D)", "ParallelThreedColumn"],
    ["Columns, Stacked (3D)",  "StackedThreedColumn"],
    # ["Line",                   "Line"],
    ["Pie (2D)",               "Pie"],
    ["Pie (3D)",               "PieThreed"]
  ]

  def chart_themes_for_select
    ZTHEMES.collect { |name| [name, name] }
  end

  def self.priority
    100
  end

  def self.available?
    File.exists?(File.join(File.dirname(__FILE__), "../../public/charts/"))
  end
end
