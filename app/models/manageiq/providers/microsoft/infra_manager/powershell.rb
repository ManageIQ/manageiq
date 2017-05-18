class ManageIQ::Providers::Microsoft::InfraManager
  module Powershell
    extend ActiveSupport::Concern

    module ClassMethods
      def execute_powershell_json(connection, script)
        results = run_powershell_script(connection, script)
        parse_json_results(results.stdout)
      end

      def execute_powershell(connection, script)
        powershell_results_to_hash(run_powershell_script(connection, script))
      end

      def run_powershell_script(connection, script)
        require 'winrm'
        log_header = "MIQ(#{self.class.name}.#{__method__})"
        results = ::WinRM::Output.new

        begin
          with_winrm_shell(connection) do |shell|
            results = shell.run(script)
            log_dos_error_results(results.stderr)
          end
        rescue Errno::ECONNREFUSED => err
          $scvmm_log.error "MIQ(#{log_header} Unable to connect to SCVMM: #{err.message})"
          raise
        end

        results
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

      def with_winrm_shell(connection, shell_type = :powershell)
        shell = connection.shell(shell_type)
        yield shell
      ensure
        shell.close
      end
    end

    def with_winrm_shell(shell_type = :powershell)
      with_provider_connection do |connection|
        begin
          shell = connection.shell(shell_type)
          yield shell
        ensure
          shell.close
        end
      end
    end

    def run_dos_command(command)
      log_header = "MIQ(#{self.class.name}##{__method__})"
      $scvmm_log.debug("#{log_header} Execute DOS command <#{command}>...")
      results = []

      _result, timings = Benchmark.realtime_block(:execution) do
        with_winrm_shell(:cmd) do |shell|
          results = shell.run(command)
          self.class.log_dos_error_results(results.stderr)
        end
      end

      $scvmm_log.debug("#{log_header} Execute DOS command <#{command}>...Complete - Timings: #{timings}")

      results
    end

    def run_powershell_script(script)
      require 'winrm'
      log_header = "MIQ(#{self.class.name}##{__method__})"
      $scvmm_log.debug("#{log_header} Execute Powershell Script...")
      results = ::WinRM::Output.new

      _result, timings = Benchmark.realtime_block(:execution) do
        with_winrm_shell do |shell|
          results = shell.run(script)
          self.class.log_dos_error_results(results.stderr)
        end
      end

      $scvmm_log.debug("#{log_header} Execute Powershell script... Complete - Timings: #{timings}")

      results
    end
  end
end
