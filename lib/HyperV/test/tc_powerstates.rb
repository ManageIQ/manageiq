$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../uitl")
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

    # !!! MAKE SURE YOU USE A VM YOU DO NOT MIND MAKING THESE CHANGES TO. !!!
    # NOTE: These test will cycle the power state on the VM.
    #vm_uuid = 'C2BDC2C6-48AA-4BD8-B3F3-5D9B0364C465'   # Windows 7
    #vm_uuid = '4C8238D0-FAF2-49D4-929F-0F85D5989820'   # SCVMM Test Server
    vm_uuid = 'A6EDDE2A-396C-47AB-A822-420B54F47D0C'   # Windows XP

    @vm = @hyperv.get_vm_by_uuid(vm_uuid)
    @vm.stop rescue nil
	end

	def teardown
    @hyperv.disconnect
	end

  def test_powerstate_changes()
    vm = @vm

    # The VM should already be stopped
    assert_raise(RuntimeError) {vm.stop}

    rc = vm.start
    assert_equal(0, rc)

    rc = vm.pause
    assert_equal(0, rc)

    rc = vm.start
    assert_equal(0, rc)

    rc = vm.suspend
    assert_equal(0, rc)

    rc = vm.start
    assert_equal(0, rc)

    rc = vm.stop
    assert_equal(0, rc)
  end
end