class EmsMicrosoft
  module Powershell
    extend ActiveSupport::Concern

    module ClassMethods
      def execute_powershell(connection, script)
        powershell_results_to_hash(run_powershell_script(connection, script))
      end

      def run_powershell_script(connection, script)
        File.open(script, "r") do |file|
          begin
            connection.run_powershell_script(file)
          rescue Errno::ECONNREFUSED => err
            $scvmm_log.error "MIQ(#{name}.#{__method__}) Unable to connect to VMM. #{err.message}"
            raise
          end
        end
      end

      def powershell_results_to_hash(results)
        powershell_xml_to_hash(powershell_results_to_xml(results))
      end

      def powershell_results_to_xml(results)
        results[:data].each.with_object("") do |d, xml|
          xml << d[:stdout].to_s
        end
      end

      def powershell_xml_to_hash(xml)
        require 'win32/miq-powershell'
        MiqPowerShell::Convert.new(xml).to_h
      end
    end
  end
end
