module ManageIQ
  module Integration
    class Environment
      def self.tmp_dir
        Rails.root.join('tmp', 'integration')
      end

      def self.run_single_worker_bin
        Rails.root.join('lib', 'workers', 'bin', 'run_single_worker.rb')
      end

      def self.ui_host
        @ui_host = "localhost"
      end

      def self.ui_port
        @ui_port = 3000
      end

      def self.ui_ping_route
        @ui_ping_route = "/api/ping"
      end
    end
  end
end
