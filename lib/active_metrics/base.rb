module ActiveMetrics
  class Base
    class << self
      attr_reader :connection_config
    end

    def self.establish_connection(config)
      @connection = nil
      @connection_config = config.symbolize_keys
    end

    def self.connection
      @connection ||= begin
        adapter = "#{connection_config[:adapter]}_adapter"
        require "active_metrics/connection_adapters/#{adapter}"
        adapter_class = ConnectionAdapters.const_get(adapter.classify)
        raw_connection = adapter_class.create_connection(connection_config)
        adapter_class.new(raw_connection)
      end
    end
  end
end
