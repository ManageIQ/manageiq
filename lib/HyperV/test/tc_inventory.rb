$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../../util")
require 'test/unit'
require 'miq-logger'
require 'MiqHyperv'

class TestVmManageMethods < Test::Unit::TestCase
	def setup
    if $log.nil?
      $log = MIQLogger.get_log(nil, __FILE__)
      $log.level = Log4r::DEBUG
    end

    # Connect and pick a VM to test against.
    @hyperv = MiqHyperV.new()
    @hyperv.connect
	end

	def teardown
    @hyperv.disconnect
	end

  def test_detection()
    h = @hyperv.hypervisorVersion
    assert_kind_of(Hash, h)
    mgmt = @hyperv.management_service
    assert_not_nil(mgmt)
  end

  def test_config_methods()
    raw_ems_data = @hyperv.ems_refresh()

    vm_uuids = raw_ems_data[:vm].keys

    vm_uuids.each do |uuid|
      vm = @hyperv.get_vm_by_uuid(uuid)

      # check that the returned memory value is 128 MB or greater
      rc = vm.getMemory
      assert(rc >= 128)

      # Check that the return CPU count is between 1 and 4
      rc = vm.getNumCPUs
      assert((1..4).include?(rc))
    end

    #rc = vm.guestInformation.inspect
  end

  def test_host_inventory
    raw_ems_data = @hyperv.ems_refresh()
    hashes = MiqHypervInventoryParser.ems_inv_to_hashes(raw_ems_data)
    hashes
  end
end