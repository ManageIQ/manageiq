module ManageIQ
  module Reporting
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
          :serialized,
          :deserialized,
          :js_load_statement      # javascript statement to reload charts
        ] => :instance
      end

      # discovery
      #
      #
      def self.instance
        @instance ||= new
      end

      def self.new
        self == ManageIQ::Reporting::Charting ? detect_available_plugin.new : super
      end

      def self.detect_available_plugin
        subclasses.select(&:available?).max_by(&:priority)
      end
    end
  end
end

# load all plugins
Dir.glob(File.join(File.dirname(__FILE__), "charting/*.rb")).each { |f| require_dependency f }
