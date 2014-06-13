require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. RedHatEnterpriseVirtualizationManagerAPI})))
require 'rhevm_api'
require 'rhevm_template'

describe RhevmTemplate do
  before do
    @service = mock('service')
    @template = RhevmTemplate.new(@service, {
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
       :memory            => 536870912,
       :stateless         => false,
       :creation_time     => "2013-09-04 16:24:20 -0400",
       :status            => {:state => "down"},
       :display           => {:type => "spice", :monitors => 1},
       :usb               => {:enabled => false},
       :cpu               => {:topology => {:sockets => 1, :cores => 1}},
       :high_availability => {:priority => 1, :enabled => false},
       :os                => {:type => "rhel5_64", :boot_order => [{:dev => "hd"}]},
       :custom_attributes => [],
       :placement_policy  => {:affinity => "migratable", :host => {}},
       :memory_policy     => {:guaranteed => 536870912},
       :guest_info        => {}
    })
  end

  context "#create_vm" do
    it "clones properties for skeletal clones" do
      options = {:clone_type => :skeletal}
      expected_data = {
        :clone_type        => :linked,
        :memory            => 536870912,
        :stateless         => false,
        :type              => "server",
        :display           => {:type => "spice", :monitors => 1},
        :usb               => {:enabled => false},
        :cpu               => {:topology => {:sockets => 1, :cores => 1}},
        :high_availability => {:priority => 1, :enabled => false},
        :os_type           => "rhel5_64"}
      @template.stub!(:nics).and_return([])
      @template.stub!(:disks).and_return([])
      @service.stub!(:blank_template).and_return(mock('blank template'))
      @service.blank_template.should_receive(:create_vm).once.with(expected_data)
      @template.create_vm(options)
    end

    it "overrides properties for linked clones" do
      expected_data = <<-EOX.chomp
<vm>
  <name>new name</name>
  <cluster id=\"fb27f9a0-cb75-4e0f-8c07-8dec0c5ab483\"/>
  <template id=\"128f9ffd-b82c-41e4-8c00-9742ed173bac\"/>
  <memory>536870912</memory>
  <stateless>false</stateless>
  <type>server</type>
  <display>
    <type>spice</type>
    <monitors>1</monitors>
  </display>
  <usb>
    <enabled>false</enabled>
  </usb>
  <cpu>
    <topology sockets="1" cores="1"/>
  </cpu>
  <high_availability>
    <priority>1</priority>
    <enabled>false</enabled>
  </high_availability>
  <os type=\"test\">
    <boot dev=\"hd\"/>
  </os>
</vm>
EOX
      response_xml = <<-EOX.chomp
<vm>
  <os type='foo'/>
  <placement_policy><affinity>foo</affinity></placement_policy>
</vm>
EOX
      options = {
        :clone_type => :linked,
        :name       => 'new name',
        :cluster    => 'fb27f9a0-cb75-4e0f-8c07-8dec0c5ab483',
        :os_type    => 'test'}
      @service.should_receive(:resource_post).once.with(:vms, expected_data).and_return(response_xml)
      @template.create_vm(options)
    end

    context "#create_new_disks_from_template" do
      before do
        @disk = RhevmDisk.new(@service, {
          :id=>"01eae62b-90df-424d-978c-beaa7eb2f7f6",
          :href=>"/api/templates/54f1b9f4-0e89-4c72-9a26-f94dcb857264/disks/01eae62b-90df-424d-978c-beaa7eb2f7f6",
          :name=>"clone_Disk1",
          :storage_domains=>[{:id=>"aa7e70e5-40d0-43e2-a605-92ce6ba652a8"}]
        })
        @template.stub(:disks).and_return([@disk])

        @vm = mock('rhevm_vm')
      end

      it "without a storage override" do
        expected_data = @disk.attributes.dup
        expected_data[:storage] = expected_data[:storage_domains].first[:id]

        @vm.should_receive(:create_disk).once.with(expected_data)
        @template.send(:create_new_disks_from_template, @vm, {})
      end

      it "with a storage override" do
        expected_data = @disk.attributes.dup
        options = {:storage => "xxxxxxxx-40d0-43e2-a605-92ce6ba652a8"}
        expected_data.merge!(options)

        @vm.should_receive(:create_disk).once.with(expected_data)
        @template.send(:create_new_disks_from_template, @vm, options)
      end
    end

    context "build_clone_xml" do
      it "Properly sets vm/cpu/topology attributes" do
        RhevmObject.stub(:object_to_id)
        xml     = @template.send(:build_clone_xml, :name => "Blank", :cluster => "default")
        nodeset = Nokogiri::XML.parse(xml).xpath("//vm/cpu/topology")
        node    = nodeset.first

        expect(nodeset.length).to       eq(1)
        expect(node["cores"].to_i).to   eq(1)
        expect(node["sockets"].to_i).to eq(1)
      end
    end
  end
end
