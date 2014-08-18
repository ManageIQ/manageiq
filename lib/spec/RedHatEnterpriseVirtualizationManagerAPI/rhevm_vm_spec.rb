require "spec_helper"
require 'active_support/core_ext'
require 'rest-client'

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. RedHatEnterpriseVirtualizationManagerAPI})))
require 'rhevm_api'
require 'rhevm_vm'

describe RhevmVm do
  before do
    @service = RhevmService.new({:server => "", :username => "", :password => ""})
    @vm = RhevmVm.new(@service, {
       :actions           => {:stop => '/api/vms/128f9ffd-b82c-41e4-8c00-9742ed173bac/stop'},
       :id                => "128f9ffd-b82c-41e4-8c00-9742ed173bac",
       :href              => "/api/vms/128f9ffd-b82c-41e4-8c00-9742ed173bac",
       :cluster           => {
         :id   => "5be5d08a-a60b-11e2-bee6-005056a217db",
         :href => "/api/clusters/5be5d08a-a60b-11e2-bee6-005056a217db"},
       :template          => {
         :id   => "00000000-0000-0000-0000-000000000000",
         :href => "/api/templates/00000000-0000-0000-0000-000000000000"},
       :name              => "bd-skeletal-clone-from-template",
       :origin            => "rhev",
       :type              => "server",
       :memory            => 536_870_912,
       :stateless         => false,
       :creation_time     => "2013-09-04 16:24:20 -0400",
       :status            => {:state => "down"},
       :display           => {:type => "spice", :monitors => 1},
       :usb               => {:enabled => false},
       :cpu               => {:sockets => 1, :cores => 1},
       :high_availability => {:priority => 1, :enabled => false},
       :os                => {:type => "unassigned", :boot_order => [{:dev => "hd"}]},
       :custom_attributes => [],
       :placement_policy  => {:affinity => "migratable", :host => {}},
       :memory_policy     => {:guaranteed => 536_870_912},
       :guest_info        => {}
    })
  end

  context "#create_disk" do
    before do
      @resource_url = "#{@vm.attributes[:href]}/disks"
      @base_options = {
        :storage            => "aa7e70e5-abcd-1234-a605-92ce6ba652a8",
        :id                 => "01eae62b-90df-424d-978c-beaa7eb2f7f6",
        :href               => "/api/templates/54f1b9f4-0e89-4c72-9a26-f94dcb857264/disks/01eae62b-90df-424d-978c-beaa7eb2f7f6",
        :name               => "bd-clone_Disk1",
        :interface          => "virtio",
        :format             => "raw",
        :image_id           => "a791ba77-8cc1-44de-9945-69f0a291cc47",
        :size               => 10737418240,
        :provisioned_size   => 10737418240,
        :actual_size        => 1316855808,
        :sparse             => true,
        :bootable           => true,
        :wipe_after_delete  => true,
        :propagate_errors   => true,
        :status             => {:state => "ok"},
        :storage_domains    => [{:id => "aa7e70e5-40d0-43e2-a605-92ce6ba652a8"}],
        :storage_domain_id  => "aa7e70e5-40d0-43e2-a605-92ce6ba652a8"
      }
      @base_data = <<-EOX.chomp
<disk>
  <name>bd-clone_Disk1</name>
  <interface>virtio</interface>
  <format>raw</format>
  <size>10737418240</size>
  <sparse>true</sparse>
  <bootable>true</bootable>
  <wipe_after_delete>true</wipe_after_delete>
  <propagate_errors>true</propagate_errors>
  <storage_domains>
    <storage_domain id=\"aa7e70e5-abcd-1234-a605-92ce6ba652a8\"/>
  </storage_domains>
</disk>
EOX
    end

    [:sparse, :bootable, :wipe_after_delete, :propagate_errors].each do |boolean_key|
      context "xml #{boolean_key.to_s} value" do
        it "set to true" do
          expected_data = @base_data
          options = @base_options.merge(boolean_key => true)

          @service.should_receive(:resource_post).once.with(@resource_url, expected_data)
          @vm.create_disk(options)
        end

        it "set to false" do
          expected_data = @base_data.gsub("<#{boolean_key.to_s}>true</#{boolean_key.to_s}>", "<#{boolean_key.to_s}>false</#{boolean_key.to_s}>")
          options = @base_options.merge(boolean_key => false)

          @service.should_receive(:resource_post).once.with(@resource_url, expected_data)
          @vm.create_disk(options)
        end

        it "unset" do
          expected_data = @base_data.gsub("  <#{boolean_key.to_s}>true</#{boolean_key.to_s}>\n", "")
          options = @base_options.dup
          options.delete(boolean_key)

          @service.should_receive(:resource_post).once.with(@resource_url, expected_data)
          @vm.create_disk(options)
        end
      end
    end
  end

  context "#create_nic" do
    before do
      @name         = 'nic_name'
      @resource_url = "#{@vm.attributes[:href]}/nics"
      @base_options = {:name => @name}
    end

    def expected_data(element)
       return <<-EOX.chomp
<nic>
  <name>#{@name}</name>
  #{element}
</nic>
EOX
    end

    it "populates the interface" do
      interface = 'interface'
      @service.should_receive(:resource_post).once.with(
          @resource_url, expected_data("<interface>#{interface}</interface>"))
      @vm.create_nic(@base_options.merge({:interface => interface}))
    end

    it "populates the network id" do
      network_id = 'network_id'
      @service.should_receive(:resource_post).once.with(
          @resource_url, expected_data("<network id=\"#{network_id}\"/>"))
      @vm.create_nic(@base_options.merge({:network_id => network_id}))
    end

    it "populates the MAC address" do
      mac_address = 'mac_address'
      @service.should_receive(:resource_post).once.with(
          @resource_url, expected_data("<mac address=\"#{mac_address}\"/>"))
      @vm.create_nic(@base_options.merge({:mac_address => mac_address}))
    end
  end

  context "#memory_reserve" do
    it "updates the memory policy guarantee" do
      memory_reserve = 1.gigabyte
      expected_data = <<-EOX.chomp
<vm>
  <memory_policy>
    <guaranteed>#{memory_reserve}</guaranteed>
  </memory_policy>
</vm>
EOX

      return_data = <<-EOX.chomp
<vm>
  <os type='dummy'/>
  <placement_policy>
    <affinity>dummy</affinity>
  </placement_policy>
</vm>
EOX

      @service.should_receive(:resource_put).once.with(
          @vm.attributes[:href],
          expected_data).and_return(return_data)
      @vm.memory_reserve = memory_reserve
    end
  end

  context "#stop" do
    it "should raise RhevmApiVmIsNotRunning if the VM is not running" do
      return_data = <<-EOX.chomp
<action>
    <fault>
        <detail>[Cannot stop VM. VM is not running.]</detail>
    </fault>
</action>
EOX

      rest_client = double('rest_client').as_null_object
      rest_client.should_receive(:post) do |&block|
        return_data.stub(:code).and_return(409)
        block.call(return_data)
      end

      @service.stub(:create_resource).and_return(rest_client)
      expect { @vm.stop }.to raise_error RhevmApiVmIsNotRunning
    end
  end
end
