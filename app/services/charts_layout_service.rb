class ChartsLayoutService
  def self.layout(perf_record, charts_folder, layout, fname = nil)
    new(perf_record, charts_folder, layout, fname).layout
  end

  def initialize(perf_record, charts_folder, layout, fname = nil)
    # DB record that has the charts, e.g. Host, EmsCluster, etc.
    @perf_record   = perf_record
    # Main folder of charts layouts
    @charts_folder = charts_folder
    # Name of the layout dir or file
    @layout        = layout
    # Optional name of the file in the layout directory, usually it's name of the base class
    @fname         = fname
  end

  def layout
    charts = build_charts
    charts.delete_if do |c|
      c.kind_of?(Hash) && c[:applies_to_method] && @perf_record &&
        @perf_record.respond_to?(c[:applies_to_method]) &&
        !@perf_record.send(c[:applies_to_method].to_sym)
    end
  end

  private

  def build_charts
    YAML.load(File.open(find_chart_path))
  end

  def find_chart_path
    if @fname
      # First, if this class specified a chart layout path, use it.
      return chart_path(@layout, @perf_record.chart_layout_path) if
        @perf_record.respond_to?(:chart_layout_path)

      # Fallback to check if there is file for specific class of the @perf_record
      path = chart_path(@layout, @perf_record.class.name.gsub(/::/, '_'))
      return path if File.exist?(path)

      # Fallback to fname, which is usually base class of the @perf_record
      chart_path(@layout, @fname)
    else
      chart_path(@layout)
    end
  end

  def chart_path(*base)
    File.join(@charts_folder, *base) + '.yaml'
  end
end
