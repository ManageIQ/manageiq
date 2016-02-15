require 'awesome_spawn'
require 'active_support/all'

RAILS_ROOT ||= Pathname.new(__dir__).join("../../..")

module ApplianceConsole
  module Logging
    LOGFILE = File.join(RAILS_ROOT, "log", "appliance_console.log")

    def self.logger
      @logger ||= default_logger
    end

    class << self
      attr_accessor :interactive
      attr_writer :logger

      def interactive?
        @interactive != false
      end
    end

    def interactive=(interactive)
      ApplianceConsole::Logging.interactive = interactive
    end

    def interactive?
      ApplianceConsole::Logging.interactive?
    end

    def interactive
      ApplianceConsole::Logging.interactive
    end

    def logger=(logger)
      ApplianceConsole::Logging.logger = logger
    end

    def logger
      ApplianceConsole::Logging.logger
    end

    def self.default_logger
      @default_logger ||= begin
        require 'logger'
        l = Logger.new(LOGFILE)
        l.level = Logger::INFO
        l
      end
    end

    def self.log_filename
      @log_filename ||= begin
        logger.logdev.filename if logger.respond_to?(:logdev)
      end
    end

    # TODO: move say_error and say_info to prompting module?
    def say_error(method, output)
      log = "\nSee #{ApplianceConsole::Logging.log_filename} for details." if ApplianceConsole::Logging.log_filename
      text = "#{method.to_s.humanize} failed with error - #{output.truncate(200)}.#{log}"
      say(text)
      press_any_key if interactive?
      raise MiqSignalError
    end

    def say_info(method, output)
      say("#{method.to_s.humanize} #{output}")
    end

    def log_and_feedback(method)
      raise ArgumentError, "No block given" unless block_given?

      log_and_feedback_info(method, "starting")

      result = nil
      begin
        result = yield
      rescue => err
        log_and_feedback_exception(err, method)
      else
        log_and_feedback_info(method, "complete")
      end
      result
    end

    def log_prefix(method)
      "MIQ(#{self.class.name}##{method}) "
    end

    def log_and_feedback_info(method, message)
      ApplianceConsole::Logging.logger.info("#{log_prefix(method)}: #{message}")
      say_info(method, message)
    end

    def log_and_feedback_exception(error, failed_method)
      feedback_error, logging = case error
                                when AwesomeSpawn::CommandResultError
                                  error_and_logging_from_command_result_error(error)
                                else
                                  error_and_logging_from_standard_error(error)
                                end

      log_error(failed_method, logging)
      say_error(failed_method, feedback_error)
    end

    def error_and_logging_from_command_result_error(error)
      result = error.result
      location = error.backtrace.detect { |loc| !loc.match(/(linux_admin|awesome_spawn)/) }
      return error.message, "Command failed: #{error.message}. Error: #{result.error}. Output: #{result.output}. At: #{location}"
    end

    def error_and_logging_from_standard_error(error)
      debugging = "Error: #{error.class.name} with message: #{error.message}"
      logging = "#{debugging}. Failed at: #{error.backtrace[0]}"
      return debugging, logging
    end

    def log_error(failed_method, debugging)
      ApplianceConsole::Logging.logger.error("#{log_prefix(failed_method)} #{debugging}")
    end
  end # module Logging
end # module ApplicationConsole
