require_relative "../test_helper"

$:.push("#{File.dirname(__FILE__)}/../../discovery/modules/")
require 'MSVirtualServerProbe'
require 'VMwareEsxVcProbe'
require 'VMwareServerProbe'
require 'MSScvmmProbe'
require 'WindowsProbe'

require 'enumerator'
require 'ostruct'
require 'test/unit'

module MiqDiscovery
	
	class TestDiscoveryModules < Test::Unit::TestCase
		def setup
#			unless $log
#				$:.push("#{File.dirname(__FILE__)}/../../util")
#				require 'miq-logger'
#
#				# Setup console logging
#				$log = MIQLogger.get_log(nil, nil)
#			end
			end
		
		def teardown
		end

		def test_MSVirtualServerProbe
#			ips = ["xxx.xxx.xxx.xxx", :msvirtualserver, nil,
#						 "xxx.xxx.xxx.xxx", nil,							nil,
#						]
#
#		  filters = [[:other, :msvirtualserver],
#								 [:other],
#								]
#
#			do_probe(MSVirtualServerProbe, ips, filters)
		end

		def test_MSScvmmProbe
#			ips = ["xxx.xxx.xxx.xxx", :scvmm, nil,
#						 "xxx.xxx.xxx.xxx", nil,		nil,
#						]
#
#		  filters = [[:other, :scvmm],
#								 [:other],
#								]
#
#			do_probe(MSScvmmProbe, ips, filters)
		end

		def test_VMwareEsxVcProbe
#			ips = ["xxx.xxx.xxx.xxx", :esx,           :linux,
#						 "xxx.xxx.xxx.xxx", :virtualcenter, :mswin,
#						]
#
#		  filters = [[:other, :virtualcenter, :esx],
#								 [:other, :esx],
#								 [:other, :virtualcenter],
#								 [:other],
#								]
#
#			do_probe(VMwareEsxVcProbe, ips, filters)
		end
		
		def test_VMwareServerProbe
#			ips = ["xxx.xxx.xxx.xxx", :vmwareserver, nil,
#						 "xxx.xxx.xxx.xxx", nil,					 nil,
#						]
#
#		  filters = [[:other, :vmwareserver],
#								 [:other],
#								]
#
#			do_probe(VMwareServerProbe, ips, filters)
		end

		def test_WindowsProbe
#			ips = ["xxx.xxx.xxx.xxx", nil, :mswin,
#						 "xxx.xxx.xxx.xxx", nil, nil,
#						]
#
#		  filters = [[:other, :msvirtualserver],
#								 [:other],
#								]
#
#			do_probe(WindowsProbe, ips, filters)
		end

	private

		def do_probe(probe, ips, filters)
			# Test probe on each ip address with each filter
			ips.each_slice(3) do |ipaddr, hypervisor, os|
				filters.each do |filter|
					if filter.include?(hypervisor)
						expected_hypervisor = hypervisor
						expected_os = os
					else
						expected_hypervisor = expected_os = nil 
					end

					ost = OpenStruct.new
					ost.os = []
					ost.hypervisor = []
					ost.ipaddr = ipaddr
					ost.discover_types = filter

					probe.probe(ost)

					assert_equal(expected_os.nil? ? 0 : 1, ost.os.length)
					assert_equal(expected_os, ost.os[0]) unless expected_os.nil?
					assert_equal(expected_hypervisor.nil? ? 0 : 1, ost.hypervisor.length)
					assert_equal(expected_hypervisor, ost.hypervisor[0]) unless expected_hypervisor.nil?
				end
			end
		end
	end
end
