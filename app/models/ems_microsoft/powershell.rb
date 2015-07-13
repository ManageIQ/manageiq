class EmsMicrosoft
  module Powershell
    extend ActiveSupport::Concern

    module ClassMethods
      def execute_powershell(connection, script)
        powershell_results_to_hash(run_powershell_script(connection, script))
      end

      def run_powershell_script(connection, script)
        log_header = "MIQ(#{self.class.name}.#{__method__})"
        File.open(script, "r") do |file|
          begin
            results = connection.run_powershell_script(file)
            log_dos_error_results(results)
            results
          rescue Errno::ECONNREFUSED => err
            $scvmm_log.error "MIQ(#{log_header} Unable to connect to SCVMM. #{err.message})"
            raise
          end
        end
      end

      def powershell_results_to_hash(results)
        powershell_xml_to_hash(powershell_results_to_xml(results))
      end

      def powershell_results_to_xml(results)
        results[:data].collect { |d| d[:stdout] }.join
      end

      def powershell_xml_to_hash(xml)
        require 'win32/miq-powershell'
        MiqPowerShell::Convert.new(xml).to_h
      end

      def log_dos_error_results(results)
        log_header = "MIQ(#{self.class.name}##{__method__})"
        error = results[:data].collect { |d| d[:stderr] }.join
        $scvmm_log.error("#{log_header} #{error}") unless error.blank?
      end

      def parse_json_results(results)
        output = results[:data].collect { |d| d[:stdout] }.join
        JSON.parse(output)
      end
    end

    def run_dos_command(command)
      log_header = "MIQ(#{self.class.name}##{__method__})"
      $scvmm_log.debug("#{log_header} Execute DOS command <#{command}>...")
      results = []

      _result, timings = Benchmark.realtime_block(:execution) do
        with_provider_connection do |connection|
          results = connection.run_cmd(command)
          self.class.log_dos_error_results(results)
        end
      end

      $scvmm_log.debug("#{log_header} Execute DOS command <#{command}>...Complete - Timings: #{timings}")

      results
    end

    def run_powershell_script(script)
      log_header = "MIQ(#{self.class.name}##{__method__})"
      $scvmm_log.debug("#{log_header} Execute Powershell Script...")
      results = []

      _result, timings = Benchmark.realtime_block(:execution) do
        with_provider_connection do |connection|
          results = connection.run_powershell_script(script)
          self.class.log_dos_error_results(results)
        end
      end

      $scvmm_log.debug("#{log_header} Execute Powershell script... Complete - Timings: #{timings}")

      results
    end
  end
end
