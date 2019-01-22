module RemoteConsole
  module ClientAdapter
    class WebMKSLegacy < WebMKS
      def issue(data)
        @driver.frame(data)
      end

      private

      def protocol
        'uint8utf8'.freeze
      end

      def path
        @record.url
      end
    end
  end
end
