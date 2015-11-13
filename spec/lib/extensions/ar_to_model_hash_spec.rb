require "spec_helper"

describe ToModelHash do
  context "to_model_hash_build_preload" do
    let(:test_disk_class)     { Class.new(ActiveRecord::Base) { self.table_name = "test_disks" } }
    let(:test_hardware_class) { Class.new(ActiveRecord::Base) { self.table_name = "test_hardwares" } }
    let(:test_vm_class)       { Class.new(ActiveRecord::Base) { self.table_name = "test_vms" } }

    before do
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
          t.integer :something
          t.integer :test_hardware_id
        end
      end

      test_disk_class.belongs_to     :test_hardware, :anonymous_class => test_hardware_class
      test_hardware_class.has_many   :test_disks,    :anonymous_class => test_disk_class
      test_hardware_class.belongs_to :test_vm,       :anonymous_class => test_vm_class
      test_vm_class.has_one          :test_hardware, :anonymous_class => test_hardware_class, :dependent => :destroy
    end

    it "virtual_column" do
      test_to_model_hash_options = {
        "cols" => ["bitness"]
      }

      test_vm_class.virtual_column :bitness, :type => :integer, :uses => :test_hardware

      options = test_vm_class.send(:to_model_hash_options_fixup, test_to_model_hash_options)
      expect(test_vm_class.new.send(:to_model_hash_build_preload, options)).to eq [:bitness]
    end

    it "virtual_column and include association column" do
      test_to_model_hash_options = {
        "cols"    => ["bitness"],
        "include" => {"test_hardware" => {"columns" => ["test_vm_id"]}}
      }

      test_vm_class.virtual_column :bitness, :type => :integer, :uses => :test_hardware

      options = test_vm_class.send(:to_model_hash_options_fixup, test_to_model_hash_options)
      expect(test_vm_class.new.send(:to_model_hash_build_preload, options)).to match_array [:bitness, :test_hardware]
    end

    it "virtual column matches included association column" do
      test_to_model_hash_options = {
        "include" => {"test_hardware" => {"columns" => ["bitness"]}}
      }

      test_vm_class.virtual_column :bitness, :type => :integer, :uses => :test_hardware

      options = test_vm_class.send(:to_model_hash_options_fixup, test_to_model_hash_options)
      expect(test_vm_class.new.send(:to_model_hash_build_preload, options)).to eq [:test_hardware]
    end

    it "virtual column on included association" do
      test_to_model_hash_options = {
        "include" => {"test_hardware" => {"columns" => ["num_disks"]}}
      }

      test_hardware_class.virtual_column :num_disks, :type => :integer, :uses => :test_disks

      options = test_vm_class.send(:to_model_hash_options_fixup, test_to_model_hash_options)
      expect(test_vm_class.new.send(:to_model_hash_build_preload, options)).to match_array [{:test_hardware => [:num_disks]}]
    end

    it "virtual and regular column includes from different associations" do
      test_to_model_hash_options = {
        "include" => [
          {"test_hardware" => {"columns" => ["num_disks"]}},
          {"test_disks"    => {"columns" => ["something"]}}
        ]
      }

      test_hardware_class.virtual_column :num_disks, :type => :integer, :uses => :test_disks

      options = test_vm_class.send(:to_model_hash_options_fixup, test_to_model_hash_options)
      expect(test_vm_class.new.send(:to_model_hash_build_preload, options)).to match_array [{:test_hardware => [:num_disks]}]
    end
  end
end
