require "spec_helper"

describe ToModelHash do
  context "to_model_hash_build_preload" do
    before do
      class TestVm < ActiveRecord::Base
        has_one :test_hardware, :dependent => :destroy
      end

      class TestHardware < ActiveRecord::Base
        has_many   :test_disks
        belongs_to :test_vm
      end

      class TestDisk < ActiveRecord::Base
        belongs_to :test_hardware
      end

      ActiveRecord::Schema.define do
        create_table :test_vms, force: true  do |t|
          t.string :name
        end

        create_table :test_hardwares, force: true  do |t|
          t.integer :bitness
          t.integer :test_vm_id
        end

        create_table :test_disks, force: true  do |t|
          t.integer :num_disks
          t.integer :test_hardware_id
        end
      end
    end

    after do
      Object.send(:remove_const, :TestVm)
      Object.send(:remove_const, :TestHardware)
      Object.send(:remove_const, :TestDisk)
    end

    it "virtual_column" do
      test_to_model_hash_options = {
        "cols" => ["bitness"]
      }

      TestVm.virtual_column :bitness,   :type => :integer, :uses => :test_hardware

      options = TestVm.send(:to_model_hash_options_fixup, test_to_model_hash_options)
      expect(TestVm.new.send(:to_model_hash_build_preload, options)).to eq [:bitness]
    end

    it "virtual_column and include association column" do
      test_to_model_hash_options = {
        "cols"    => ["bitness"],
        "include" => {"test_hardware" => {"columns" => ["test_vm_id"]}}
      }

      TestVm.virtual_column :bitness, :type => :integer, :uses => :test_hardware

      options = TestVm.send(:to_model_hash_options_fixup, test_to_model_hash_options)
      expect(TestVm.new.send(:to_model_hash_build_preload, options)).to match_array [:bitness, :test_hardware]
    end

    it "virtual column matches included association column" do
      test_to_model_hash_options = {
        "include" => {"test_hardware" => {"columns" => ["bitness"]}}
      }

      TestVm.virtual_column :bitness, :type => :integer, :uses => :test_hardware

      options = TestVm.send(:to_model_hash_options_fixup, test_to_model_hash_options)
      expect(TestVm.new.send(:to_model_hash_build_preload, options)).to eq [:test_hardware]
    end

    it "virtual column on included association" do
      # TODO: This fails if following one of the other tests that add a virtual column to TestVm.
      # It appears the .parent_class object_id (in to_model_hash_build_preload) is the same
      # across tests, is the remove_const not working in the after?
      test_to_model_hash_options = {
        "include" => {"test_hardware" => {"columns" => ["num_disks"]}}
      }

      TestHardware.virtual_column :num_disks, :type => :integer, :uses => :test_disks

      options = TestVm.send(:to_model_hash_options_fixup, test_to_model_hash_options)
      expect(TestVm.new.send(:to_model_hash_build_preload, options)).to match_array [{:test_hardware => [:num_disks]}]
    end
  end
end
