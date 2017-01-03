describe ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Parser do
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

      result = ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Parser.vm_inv_to_disk_hashes(disk_inv, {})
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
      result = ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Parser.vm_inv_to_custom_attribute_hashes(inv)
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

  context "#extract_host_os_name" do
    it "should extract the host OS name from os element" do
      host_inv = {
        :type => "some_os_type",
        :os   => {
          :type => "expected_os_type"
        }
      }
      result = ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Parser.extract_host_os_name(host_inv)
      expect(result).to eq("expected_os_type")
    end

    it "should extract the host OS name from type element" do
      host_inv = {
        :type => "some_os_type",
      }
      result = ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Parser.extract_host_os_name(host_inv)
      expect(result).to eq("some_os_type")
    end

    it "should call #extract_host_os_name as part of host OS parsing" do
      host_inv = {
        :type => "some_os_type",
      }
      expect(ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Parser).to receive(:extract_host_os_name)
      ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Parser.host_inv_to_os_hash(host_inv, "")
    end
  end
end
