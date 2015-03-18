module Vmdb
  module PermissionStores
    class Configuration
      attr_accessor :backend
      attr_accessor :options

      def initialize
        @options = {}
      end

      def create
        PermissionStores.create self
      end

      def load
        require "permission_stores/#{backend}"
      end
    end

    class << self
      attr_accessor :configuration, :instance
    end

    def self.configure
      @configuration = Configuration.new
      yield @configuration
    end

    def self.initialize!
      @configuration.load
      @instance = @configuration.create
    end
  end
end
