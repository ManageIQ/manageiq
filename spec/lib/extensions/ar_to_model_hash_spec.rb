require "spec_helper"

describe ToModelHash do
  class TestVm < ActiveRecord::Base
    has_one        :test_hardware, :dependent => :destroy
    virtual_column :bitness,   :type => :integer, :uses => :test_hardware
    virtual_column :num_disks, :type => :integer, :uses => {:test_hardware => :test_disks}
  end

  class TestHardware < ActiveRecord::Base
    has_many   :test_disks
    belongs_to :test_vm
  end

  class TestDisk < ActiveRecord::Base
    belongs_to :test_hardware
  end

  let(:test_to_model_hash_options) do
    {
      "cols"    => ["name"],
      "include" =>
        {"test_hardware" =>
          {
            "columns" => ["bitness"],
            "include" => {"test_disk" => {"columns" => ["num_disks"]}}
          }
        }
    }
  end

  it "to_model_hash_build_preload" do
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

    options = TestVm.send(:to_model_hash_options_fixup, test_to_model_hash_options)
    expect(TestVm.new.send(:to_model_hash_build_preload, options)).to eq [{:test_hardware => [:test_disk]}]
  end
end
