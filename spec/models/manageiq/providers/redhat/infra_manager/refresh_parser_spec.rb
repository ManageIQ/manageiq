require "spec_helper"

describe ManageIQ::Providers::Redhat::InfraManager::RefreshParser do
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

      result = ManageIQ::Providers::Redhat::InfraManager::RefreshParser.vm_inv_to_disk_hashes(disk_inv, {})
      hashes = result.collect do |d|
        {:interface   => d[:controller_type],
         :location    => d[:location],
         :device_name => d[:device_name]}
      end

      expect(hashes).to eq([
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
      ])
    end
  end

  context "#vm_inv_to_custom_attribute_hashes" do
    it "should truncate the custom attribute value" do
      inv = {
        :custom_attributes => [
          :name  => 'custom_attribute',
          :value => "0" * 1000
        ]
      }
      result = ManageIQ::Providers::Redhat::InfraManager::RefreshParser.vm_inv_to_custom_attribute_hashes(inv)
      expect(result).to eq([
        {
          :section => "custom_field",
          :name    => "custom_attribute",
          :value   => "#{"0" * 252}...",
          :source  => "VC"
        }
      ])
    end
  end
end
