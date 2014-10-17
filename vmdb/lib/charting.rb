class Charting
  class << self
    extend Forwardable
    delegate [
      :backend,               # charting backend name; FIXME: remove this method
      :render_format,
      :format,                # format for Ruport renderer
      :load_helpers,
      :data_ok?,
      :sample_chart,
      :chart_names_for_select,
      :chart_themes_for_select,
      :js_load_statement      # javascript statement to reload charts
    ] => :instance
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
