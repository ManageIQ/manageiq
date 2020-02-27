module ManageIQ
  module Reporting
    class C3Charting < ManageIQ::Reporting::Charting
      # for Charting.detect_available_plugin
      def self.available?
        true
      end

      # for Charting.detect_available_plugin
      def self.priority
        1000
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
        :c3
      end

      # called from each ApplicationController instance
      def load_helpers(klass)
        klass.instance_eval do
          helper ManageIQ::Reporting::Formatter::C3Helper
        end
      end

      def data_ok?(data)
        obj = YAML.load(data)
        !!obj && obj.kind_of?(Hash) && !obj[:options]
      rescue Psych::SyntaxError, ArgumentError
        false
      end

      def sample_chart(_options, _report_theme)
        sample = {
          :data => {
            :axis    => {},
            :tooltip => {},
            :columns => [
              ['data1', 30, 200, 100, 400, 150, 250],
              ['data2', 50, 20, 10, 40, 15, 25],
              ['data3', 10, 25, 10, 250, 10, 30]
            ],
          },
          :miqChart => _options[:graph_type],
          :miq      => { :zoomed => false }
        }
        sample[:data][:groups] = [['data1','data2', 'data3']] if _options[:graph_type].include? 'Stacked'
        sample
      end

      def js_load_statement(delayed = false)
        delayed ? 'setTimeout(function(){ load_c3_charts(); }, 100);' : 'load_c3_charts();'
      end

      # list of available chart types - in options_for_select format
      def chart_names_for_select
        CHART_NAMES
      end

      # list of themes - in options_for_select format
      def chart_themes_for_select
        [%w(Default default)]
      end

      def serialized(data)
        data.try(:to_yaml)
      end

      def deserialized(data)
        YAML.load(data)
      end

      CHART_NAMES = [
        ["Bars (2D)",             "Bar"],
        ["Bars, Stacked (2D)",    "StackedBar"],
        ["Columns (2D)",          "Column"],
        ["Columns, Stacked (2D)", "StackedColumn"],
        ["Donut (2D)",            "Donut"],
        ["Pie (2D)",              "Pie"],
        ["Line (2D)",             "Line"],
        ["Area (2D)",             "Area"],
        ["Area, Stacked (2D)",    "StackedArea"],
      ]
    end
  end
end
