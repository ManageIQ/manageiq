require "spec_helper"

module MiqAeServiceModelSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceVm do
    before(:each) do
      @vm = FactoryGirl.create(:vm_vmware)
      @ae_vm = MiqAeMethodService::MiqAeServiceVmVmware.new(@vm.id)
    end

    it ".base_model" do
      MiqAeMethodService::MiqAeServiceVmVmware.base_model.should == MiqAeMethodService::MiqAeServiceVm
    end

    it ".base_class" do
      MiqAeMethodService::MiqAeServiceVmVmware.base_class.should == MiqAeMethodService::MiqAeServiceVmOrTemplate
    end

    it "vm should be valid" do
      @vm.should be_kind_of(Vm)
      @vm.should_not be_nil
      @vm.id.should_not be_nil
    end

    it "ae_vm should be valid" do
      @ae_vm.should be_kind_of(MiqAeMethodService::MiqAeServiceVm)
      @ae_vm.instance_variable_get("@object").should == @vm
    end

    it "ae_vm should have a special inspect method" do
      # #<MiqAeServiceVm:0x82c9ac48 @object=#<Vm id: 102, vendor: "vmware", format: nil, version: nil, name: "vm_3", description: nil, location: "[storage] vm_3/vm_3.vmx", config_xml: nil, autostart: nil, host_id: nil, last_sync_on: nil, created_on: "2011-02-24 21:08:14", updated_on: "2011-02-24 21:08:14", storage_id: nil, guid: "318e7116-405a-11e0-bbd9-001f5bee6a67", service_id: nil, ems_id: nil, last_scan_on: nil, last_scan_attempt_on: nil, uid_ems: "318e597e-405a-11e0-bbd9-001f5bee6a67", retires_on: nil, retired: nil, boot_time: nil, tools_status: nil, standby_action: nil, power_state: nil, state_changed_on: nil, previous_state: nil, connection_state: nil, last_perf_capture_on: nil, blackbox_exists: nil, blackbox_validated: nil, registered: nil, busy: nil, smart: nil, retirement: nil, memory_reserve: nil, memory_reserve_expand: nil, memory_limit: nil, memory_shares: nil, memory_shares_level: nil, cpu_reserve: nil, cpu_reserve_expand: nil, cpu_limit: nil, cpu_shares: nil, cpu_shares_level: nil, cpu_affinity: nil, ems_created_on: nil, template: false, evm_owner_id: nil, ems_ref_obj: nil, miq_group_id: nil, operating_ranges: nil, vdi: false>, @associations=["datacenter", "ems_blue_folder", "ems_cluster", "ems_folder", "ext_management_system", "hardware", "host", "miq_provision", "operating_system", "owner", "resource_pool", "storage"]>
      inspect = @ae_vm.inspect
      inspect[0,2].should == '#<'
      inspect[-1,1].should == '>'
#      puts "INSPECT: #{inspect}"
    end

    it "ae_vm should have an associations method" do
      @ae_vm.associations.should be_kind_of(Array)
      # methods = (@ae_vm.methods - Object.methods).sort.inspect
      # puts "METHODS on INSTANCE: #{methods}"
      # methods = (MiqAeMethodService::MiqAeServiceVm.methods - Object.methods).sort.inspect
      # puts "METHODS on CLASS: #{methods}"
      # puts "ASSOCIATION on INSTANCE: #{@ae_vm.associations.inspect}"
      # puts "ASSOCIATION on CLASS: #{MiqAeMethodService::MiqAeServiceVm.associations.inspect}"
    end

    describe "#tag_assign" do
      let(:category)    { FactoryGirl.create(:classification) }
      let(:tag)         { FactoryGirl.create(:classification_tag, :parent_id => category.id) }

      it "can assign an exiting tag to ae_vm" do
        @ae_vm.tag_assign("#{category.name}/#{tag.name}").should be_true
        @ae_vm.tagged_with?(category.name, tag.name).should be_true
      end

      it "cannot assign a non-existing tag to ae_vm, but no error is raised" do
        @ae_vm.tag_assign("#{category.name}/non_exisiting_tag").should be_true
        @ae_vm.tagged_with?(category.name, 'non_exisiting_tag').should be_false
      end
    end

    describe "#tag_unassign" do
      let(:category)    { FactoryGirl.create(:classification) }
      let(:tag)         { FactoryGirl.create(:classification_tag, :parent_id => category.id) }
      let(:another_tag) { FactoryGirl.create(:classification_tag, :parent_id => category.id) }

      context "with assigned tags" do
        before do
          @ae_vm.tag_assign("#{category.name}/#{tag.name}")
        end

        it "can unassign a tag from ae_vm" do
          @ae_vm.tag_unassign("#{category.name}/#{tag.name}").should be_true
          @ae_vm.tagged_with?(category.name, tag.name).should be_false
        end

        it "unassigns only specified tag from ae_vm but not other tags from the same category" do
          @ae_vm.tag_assign("#{category.name}/#{another_tag.name}").should be_true

          @ae_vm.tag_unassign("#{category.name}/#{tag.name}").should be_true
          @ae_vm.tagged_with?(category.name, another_tag.name).should be_true
        end
      end

      it "does not raise an error when attempts to unassign a non-existing tag" do
        @ae_vm.tag_unassign("#{category.name}/non_exisiting_tag").should be_true
      end
    end
  end
end

# NOTE: Old style testing against EMS, Vm, Host, EmsEvent, and MiqServer service
#   models.  These tests test the basic service model methods and can be removed
#   in favor of the same tests against any single one of those classes.
#
require "spec_helper"
#  require "#{File.dirname(__FILE__)}/../lib/engine/miq_ae_service"
#  require "#{File.dirname(__FILE__)}/../lib/engine/miq_ae_service_model_base"
#  Dir.new("#{File.dirname(__FILE__)}/../lib/service_models").each { |fname|
#    require File.join(File.dirname(__FILE__), "../lib/service_models", fname) if File.extname(fname) == ".rb"
#  }
#
#  # Group of common tests for all service models
#  %w{ExtManagementSystem Vm Host EmsEvent MiqServer}.each do |m|
#    Kernel.const_set("MiqAeService#{m}Test",
#      Class.new(Test::Unit::TestCase) do
#        include MiqAeEngine
#
#        def setup
#          /(MiqAeService(.+))Test/ =~ self.class.name
#          @klass = MiqAeMethodService.const_get($1)
#          @model = Kernel.const_get($2)
#
#          recs = @model.find(:all, :limit => 2)
#          raise "Can't run test unless 2 records are in the #{@model.name.underscore.pluralize} table" if recs.length < 2
#          @o1, @o2 = *recs[0..1]
#          @ids = [@o1.id, @o2.id]
#        end
#
#        def teardown
#        end
#
#        def test_find_by_id
#          o = nil
#          assert_nothing_raised { o = @klass.find(@o1.id) }
#          assert_kind_of @klass, o
#          assert_equal @o1, o.instance_variable_get("@object")
#
#          assert_raise(MiqAeException::ServiceNotFound) { o = @klass.find(-1) }
#        end
#
#        def test_find_by_multiple_ids
#          objs = nil
#          assert_nothing_raised { objs = @klass.find(@ids) }
#          assert_kind_of Array, objs
#          objs.each { |o| assert_kind_of @klass, o }
#
#          objs = objs.collect { |o| o.instance_variable_get("@object") }
#          assert objs.include?(@o1)
#          assert objs.include?(@o2)
#        end
#
#        def test_find_by_multiple_ids_with_arguments
#          objs = nil
#          assert_nothing_raised { objs = @klass.find(@ids, :order => "id DESC") }
#          ids_rev = objs.collect { |o| o['id'] }
#          assert_equal @ids.sort.reverse, ids_rev
#        end
#
#        def test_new_by_id
#          o = nil
#          assert_nothing_raised { o = @klass.find(@o1.id) }
#          assert_kind_of @klass, o
#          assert_equal @o1, o.instance_variable_get("@object")
#
#          assert_raise(MiqAeException::ServiceNotFound) { o = @klass.new(-1) }
#        end
#
#        def test_new_by_obj
#          o = nil
#          assert_nothing_raised { o = @klass.new(@o1) }
#          assert_kind_of @klass, o
#          assert_equal @o1, o.instance_variable_get("@object")
#        end
#
#        def test_attributes
#          o = @klass.new(@o1)
#          assert_equal @o1.attributes, o.attributes
#
#          a = 'name'
#          a = 'event_type' if @model == EmsEvent
#          a_val = "TEST_ATTRS"
#
#          assert_equal @o1.send(a), o[a]
#          o[a] = a_val
#          assert_equal a_val, o[a]
#          o.reload
#          assert_equal @o1.send(a), o[a]
#        end
#      end
#    )
#  end
#
#  # Add another test to the EmsEvent test
#  class MiqAeServiceEmsEventTest < Test::Unit::TestCase
#
#    def test_wrap_object_call
#      e = @klass.new(@o1)
#
#      %w{vm src_vm dest_vm host src_host dest_host ext_management_system}.each do |m|
#        o = e.send(m)
#        o = o.instance_variable_get("@object") unless o.nil?
#        assert_equal @o1.send(m), o
#      end
#    end
#
#  end
