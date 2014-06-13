class Charting
  # charting backend name
  # FIXME: remove this method
  def self.backend
    instance.backend
  end

  def self.render_format
    instance.render_format
  end

  # format for Ruport renderer
  def self.format
    instance.format
  end

  # javascript statement to reload charts
  def self.js_load_statement(delayed = false)
    instance.js_load_statement(delayed)
  end

  def self.load_helpers(klass)
    instance.load_helpers(klass)
  end

  def self.data_ok?(data)
    instance.data_ok?(data)
  end

  def self.sample_chart(options, report_theme)
    instance.sample_chart(options, report_theme)
  end

  def self.chart_names_for_select
    instance.chart_names_for_select
  end

  # discovery
  #
  #
  def self.instance
    @instance ||= new
  end

  private

  def self.new
    self == Charting ? detect_available_plugin.new : super
  end

  def self.detect_available_plugin
    available = subclasses.select(&:available?)
    available.max { |klass_a, klass_b| klass_a.priority <=> klass_b.priority }
  end
end

# load all plugins
Dir.glob(File.join(File.dirname(__FILE__), "charting/*.rb")).each { |f| require_dependency f }
