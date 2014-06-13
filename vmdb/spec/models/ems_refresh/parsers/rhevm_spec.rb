require "spec_helper"

describe EmsRefresh::Parsers::Rhevm do

  context "#vm_inv_to_disk_hashes" do

    it "should assign location by boot order and name" do
      disk_inv = {:disks => [
        {
          :interface       => 'virtio',
          :name            => 'my disk 2',
          :bootable        => false,
          :storage_domains => []
        },
        { 
          :interface       => 'virtio',
          :name            => 'other disk 1',
          :bootable        => false,
          :storage_domains => []
        },
        {
          :interface       => 'virtio',
          :name            => 'abc',
          :bootable        => true,
          :storage_domains => []
        },
        {
          :interface       => 'ide',
          :name            => 'abc',
          :bootable        => false,
          :storage_domains => []
        }
      ]}

      result = EmsRefresh::Parsers::Rhevm.vm_inv_to_disk_hashes(disk_inv, {})
      result.collect { |d| { :interface => d[:controller_type], :location => d[:location], :device_name => d[:device_name] } }.should == [
        {
          :interface   => 'virtio',
          :location    => '0',
          :device_name => 'abc'
        },
        {
          :interface   => 'virtio',
          :location    => '1',
          :device_name => 'other disk 1'
        },
        {
          :interface   => 'virtio',
          :location    => '2',
          :device_name => 'my disk 2'
        },
        {
          :interface   => 'ide',
          :location    => '0',
          :device_name => 'abc'
        }
      ]
    end

  end

end
