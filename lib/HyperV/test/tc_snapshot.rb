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
    # NOTE: These test will destroy any snapshots on the VM.
    #vm_uuid = 'C2BDC2C6-48AA-4BD8-B3F3-5D9B0364C465'   # Windows 7
    #vm_uuid = '4C8238D0-FAF2-49D4-929F-0F85D5989820'   # SCVMM Test Server
    vm_uuid = 'A6EDDE2A-396C-47AB-A822-420B54F47D0C'   # Windows XP

    @vm = @hyperv.get_vm_by_uuid(vm_uuid)
    @vm.removeAllSnapshots rescue nil
	end

	def teardown
    @hyperv.disconnect
	end

  def test_snapshot_management()
    vm = @vm

    len = vm.snapshotInfo.length
    assert_equal(0, len)

    x = ["MIQ Test 1 - #{Time.now}", "MIQ Snapshot time #{Time.now.utc.iso8601}"]
    vm.createSnapshot(x[0], x[1], nil, nil)
    rc = vm.removeSnapshotByDescription("Hello World")
    assert_equal(false, rc)
    rc = vm.removeSnapshotByDescription(x[1])
    assert_equal(true, rc)
    len = vm.snapshotInfo.length
    assert_equal(0, len)

    assert_nothing_raised {vm.createEvmSnapshot("#{Time.now}")}
    assert_raise(MiqException::MiqVmSnapshotError) { vm.createEvmSnapshot("#{Time.now}") }
    vm.removeAllSnapshots
    len = vm.snapshotInfo.length
    assert_equal(0, len)

    vm.createSnapshot("MIQ Test 1 - #{Time.now}", "MIQ Snapshot time #{Time.now.utc.iso8601}", nil, nil)
    snMiq2 = vm.createSnapshot("MIQ Test 2 - #{Time.now}", "MIQ Snapshot time #{Time.now.utc.iso8601}", nil, nil)
    len = vm.snapshotInfo.length
    assert_equal(2, len)

    sn_root = vm.snapshotInfo.detect {|s| s.Parent.nil?}
    vm.revertToSnapshot(sn_root.InstanceID)
    vm.createSnapshot("MIQ Test 3 - #{Time.now}", "MIQ Snapshot time #{Time.now.utc.iso8601}", nil, nil)
    len = vm.snapshotInfo.length
    assert_equal(3, len)

    vm.removeSnapshot(sn_root.InstanceID)
    len = vm.snapshotInfo.length
    assert_equal(2, len)

    vm.revertToSnapshot(snMiq2.InstanceID)
    vm.createSnapshot("MIQ Test 4 - #{Time.now}", "MIQ Snapshot time #{Time.now.utc.iso8601}", nil, nil)
    len = vm.snapshotInfo.length
    assert_equal(3, len)

    vm.revertToCurrentSnapshot
    vm.removeSnapshot(snMiq2.InstanceID)
    len = vm.snapshotInfo.length
    assert_equal(2, len)

    vm.removeAllSnapshots
    len = vm.snapshotInfo.length
    assert_equal(0, len)
  end
end