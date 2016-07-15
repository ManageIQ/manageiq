class ManageIQ::Providers::Microsoft::InfraManager
  module Powershell
    extend ActiveSupport::Concern

    module ClassMethods
      def execute_powershell(connection, script)
        powershell_results_to_hash(run_powershell_script(connection, script))
      end

      def run_powershell_script(connection, script)
        log_header = "MIQ(#{self.class.name}.#{__method__})"
        script = ""
        File.open(script, "r") do |file|
          script << file.read
        end
        begin
          results = connection.shell(:powershell).run(script)
          log_dos_error_results(results)
          results
        rescue Errno::ECONNREFUSED => err
          $scvmm_log.error "MIQ(#{log_header} Unable to connect to SCVMM. #{err.message})"
          raise
        end
      end

      def powershell_results_to_hash(results)
        powershell_xml_to_hash(decompress_results(results))
      end

      def powershell_xml_to_hash(xml)
        require 'win32/miq-powershell'
        MiqPowerShell::Convert.new(xml).to_h
      end

      def log_dos_error_results(results)
        log_header = "MIQ(#{self.class.name}##{__method__})"
        error = results.respond_to?(:stderr) ? parse_xml_error_string(results.stderr) : results
        $scvmm_log.error("#{log_header} #{error}") unless error.blank?
      end

      def parse_json_results(results)
        output = decompress_results(results)
        JSON.parse(output)
      end

      def decompress_results(results)
        results = results.stdout if results.respond_to?(:stdout)
        begin
          ActiveSupport::Gzip.decompress(Base64.decode64(results))
        rescue Zlib::GzipFile::Error # Not in gzip format
          results
        end
      end

      # Parse an ugly XML error string into something much more readable.
      #
      def parse_xml_error_string(str)
        require 'nokogiri'
        str = str.sub("#< CLIXML\r\n", '') # Illegal, nokogiri can't cope
        doc = Nokogiri::XML::Document.parse(str)
        doc.remove_namespaces!

        text = doc.xpath("//S").map(&:text).join
        array = text.split(/_x\h{1,}_/) # Split on stuff like '_x000D_'
        array.delete('') # Delete empty elements

        array.inject('') do |string, element|
          break string if element =~ /at line:\d+/i
          string << element
        end
      end
    end

    def run_dos_command(command)
      log_header = "MIQ(#{self.class.name}##{__method__})"
      $scvmm_log.debug("#{log_header} Execute DOS command <#{command}>...")
      results = []

      _result, timings = Benchmark.realtime_block(:execution) do
        with_provider_connection do |connection|
          results = connection.shell(:cmd).run(command)
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
          script = ""
          File.open(script, "r") do |file|
            script << file.read
          end
          results = connection.shell(:powershell).run(script)
          self.class.log_dos_error_results(results)
        end
      end

      $scvmm_log.debug("#{log_header} Execute Powershell script... Complete - Timings: #{timings}")

      results
    end
  end
end
