require "spec_helper"

describe ToModelHash do
  context "to_model_hash_build_preload" do
    let(:test_disk_class)     { Class.new(ActiveRecord::Base) { self.table_name = "test_disks" } }
    let(:test_hardware_class) { Class.new(ActiveRecord::Base) { self.table_name = "test_hardwares" } }
    let(:test_vm_class)       { Class.new(ActiveRecord::Base) { self.table_name = "test_vms" } }
    let(:fixed_options)       { test_vm_class.send(:to_model_hash_options_fixup, @test_to_model_hash_options) }

    before do
      silence_stream($stdout) do
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
      end

      test_disk_class.belongs_to     :test_hardware, :anonymous_class => test_hardware_class
      test_hardware_class.has_many   :test_disks,    :anonymous_class => test_disk_class
      test_hardware_class.belongs_to :test_vm,       :anonymous_class => test_vm_class
      test_vm_class.has_one          :test_hardware, :anonymous_class => test_hardware_class, :dependent => :destroy
    end

    it "included column" do
      @test_to_model_hash_options = {
        "include" => {"test_hardware" => {"columns" => ["bitness"]}}
      }

      expect(test_vm_class.new.send(:to_model_hash_build_preload, fixed_options)).to eq [:test_hardware]
    end

    it "nested included columns" do
      @test_to_model_hash_options = {
        "include" => {
          "test_hardware" => {
            "columns" => ["bitness"],
            "include" => {"test_disks" => {"columns" => ["num_disks"]}}
          }
        }
      }

      expect(test_vm_class.new.send(:to_model_hash_build_preload, fixed_options)).to eq [{:test_hardware => [:test_disks]}]
    end

    context "virtual columns" do
      it "virtual column on main table" do
        @test_to_model_hash_options = {
          "cols" => ["bitness"]
        }

        test_vm_class.virtual_column :bitness, :type => :integer, :uses => :test_hardware
        expect(test_vm_class.new.send(:to_model_hash_build_preload, fixed_options)).to eq([:bitness])
      end

      it "virtual column and included column" do
        @test_to_model_hash_options = {
          "cols"    => ["bitness"],
          "include" => {"test_hardware" => {"columns" => ["test_vm_id"]}}
        }

        test_vm_class.virtual_column :bitness, :type => :integer, :uses => :test_hardware
        expect(test_vm_class.new.send(:to_model_hash_build_preload, fixed_options)).to match_array [:bitness, :test_hardware]
      end

      it "virtual column matches included association column" do
        @test_to_model_hash_options = {
          "include" => {"test_hardware" => {"columns" => ["bitness"]}}
        }

        test_vm_class.virtual_column :bitness, :type => :integer, :uses => :test_hardware
        expect(test_vm_class.new.send(:to_model_hash_build_preload, fixed_options)).to eq [:test_hardware]
      end

      it "included association virtual column " do
        @test_to_model_hash_options = {
          "include" => {"test_hardware" => {"columns" => ["num_disks"]}}
        }

        test_hardware_class.virtual_column :num_disks, :type => :integer, :uses => :test_disks
        expect(test_vm_class.new.send(:to_model_hash_build_preload, fixed_options)).to match_array [{:test_hardware => [:num_disks]}]
      end

      it "virtual and regular column included from different associations" do
        @test_to_model_hash_options = {
          "include" =>  {
            "test_hardware" => {"columns" => ["num_disks"]},
            "test_disks"    => {"columns" => ["something"]}
          }
        }

        test_hardware_class.virtual_column :num_disks, :type => :integer, :uses => :test_disks
        expect(test_vm_class.new.send(:to_model_hash_build_preload, fixed_options)).to match_array [{:test_hardware => [:num_disks]}]
      end
    end
  end
end
