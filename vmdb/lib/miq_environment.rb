require 'platform'

module MiqEnvironment
  class Process
    def self.is_rails_server?
      return @is_rails_server unless @is_rails_server.nil?
      return @is_rails_server = File.basename($PROGRAM_NAME) =~ /rackup|thin/ || (File.basename($PROGRAM_NAME) == "rails" && !!defined?(Rails::Server))
    end

    def self.is_rails_console?
      return @is_rails_console unless @is_rails_console.nil?
      return @is_rails_console = File.basename($PROGRAM_NAME) == "rails" && !!defined?(Rails::Console)
    end

    def self.is_rails_runner?
      return @is_rails_runner unless @is_rails_runner.nil?
      return @is_rails_runner = !is_rails_server? && !is_rails_console?
    end

    def self.is_ui_worker_via_command_line?
      return @is_ui_worker_via_command_line unless @is_ui_worker_via_command_line.nil?
      #TODO: Support rdebug-ide
      return @is_ui_worker_via_command_line = ( is_rails_server? && ENV['PORT'].to_s.empty? ) || !ENV['SPEC_UI'].to_s.empty?
    end

    def self.is_ui_worker_via_evm_server?
      return @is_ui_worker_via_evm_server unless @is_ui_worker_via_evm_server.nil?
      return @is_ui_worker_via_evm_server = is_rails_server? && ENV['PORT'].to_s =~ /^3[0-9]+/
    end

    def self.is_ui_worker?
      return @is_ui_worker unless @is_ui_worker.nil?
      return @is_ui_worker = is_ui_worker_via_command_line? || is_ui_worker_via_evm_server?
    end

    def self.is_web_service_worker?
      return @is_web_service_worker unless @is_web_service_worker.nil?
      return @is_web_service_worker = is_rails_server? && ENV['PORT'].to_s =~ /^4[0-9]+/
    end
    class << self; alias :is_web_service_worker_via_evm_server? :is_web_service_worker?; end

    def self.is_web_server_worker?
      return @is_web_server_worker unless @is_web_server_worker.nil?
      return @is_web_server_worker = is_ui_worker? || is_web_service_worker?
    end

    def self.is_worker?
      return @is_worker unless @is_worker.nil?
      return @is_worker = is_non_web_server_worker? || is_web_server_worker?
    end

    def self.is_non_web_server_worker?
      return @is_non_web_server_worker unless @is_non_web_server_worker.nil?
      # ARGV: ["priority_worker", "MiqPriorityWorker", "--queue_name", "generic", "--guid", "33d93972-56ff-11e0-98ac-001f5bee6a67"]
      # rails runner eats /var/www/miq/vmdb/lib/workers/bin/worker.rb which was ARGV[0]
      klass = ARGV[1].constantize rescue NilClass
      return @is_non_web_server_worker = is_rails_runner? && klass.hierarchy.include?(MiqWorker)
    end

    def self.is_evmserver?
      return @is_evmserver unless @is_evmserver.nil?
      @is_evmserver = is_rails_runner? && !ENV['EVMSERVER'].blank?

      # Unset the variable so subprocesses don't inherit it
      ENV['EVMSERVER'] = nil
      return @is_evmserver
    end
  end

  class Command
    EVM_KNOWN_COMMANDS = %w( memcached memcached-tool service apachectl nohup)

    def self.supports_memcached?
      return @supports_memcached unless @supports_memcached.nil?
      return @supports_memcached = self.is_linux? && self.is_appliance? && self.supports_command?('memcached') && self.supports_command?('memcached-tool') && self.supports_command?('service')
    end

    def self.supports_apache?
      return @supports_apache unless @supports_apache.nil?
      return @supports_apache = self.is_appliance? && self.supports_command?('apachectl')
    end

    def self.supports_nohup_and_backgrounding?
      return @supports_nohup unless @supports_nohup.nil?
      return @supports_nohup = self.is_appliance? && self.supports_command?('nohup')
    end

    def self.is_appliance?
      return @is_appliance unless @is_appliance.nil?
      return @is_appliance = self.is_linux? && File.exist?('/var/www/miq/vmdb')
    end

    def self.is_production?
      # Note: This method could be called outside of Rails, so check defined?(Rails)
      # Assume production if not defined or if set to 'production'
      return defined?(Rails) ? Rails.env.production? : true
    end

    def self.is_linux?
      return @is_linux unless @is_linux.nil?
      return @is_linux = (Platform::IMPL == :linux)
    end

    def self.rake_command
      "rake"
    end

    def self.runner_command
      "#{rails_command} runner"
    end

    def self.rails_command
      "rails"
    end

    private

    def self.supports_command?(cmd)
      return false unless EVM_KNOWN_COMMANDS.include?(cmd)
      require "#{File.join(File.dirname(__FILE__), "../../lib/util/runcmd")}"

      begin
        # If 'which apachectl' returns non-zero, it wasn't found
        MiqUtil.runcmd("#{self.which} #{cmd}")
      rescue
        false
      else
        true
      end
    end

    def self.which
      case Platform::IMPL
      when :linux
        "which"
      else
        raise "Not yet supported platform: #{Platform::IMPL}"
      end
    end
  end
end
