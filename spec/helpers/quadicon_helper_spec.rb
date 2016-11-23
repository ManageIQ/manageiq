require 'wbem'

RSpec.shared_examples :quadicon_with_link do
  it 'renders a quadicon with a link by default' do
    expect(subject).to have_selector('div.quadicon')
    expect(subject).to have_selector('a')
  end
end

RSpec.shared_examples :shield_img_with_policies do
  context "when item has policies" do
    it 'has a shield icon' do
      item.add_policy(FactoryGirl.create(:miq_policy))

      expect(subject).to have_selector('img[src*="shield"]')
    end
  end
end

RSpec.shared_examples :host_vendor_icon do |cls|
  it "renders a quadicon with #{cls}-class vendor img" do
    vendor = item.vmm_vendor_display.downcase
    expect(host_quad).to have_selector("div[class*='#{cls}'] img[src*='vendor-#{vendor}']")
  end
end

RSpec.shared_examples :no_link_for_listnav do
  let(:options) { {:typ => :listnav} }

  it 'has no link when type is listnav' do
    expect(subject).not_to have_selector("a")
  end
end

RSpec.shared_examples :has_reflection do
  it 'has a reflection' do
    expect(subject).to have_selector("img[src*='reflection']")
  end
end

RSpec.shared_examples :has_base_img do
  it 'includes a base-single img' do
    expect(subject).to have_selector("img[src*='base']")
    expect(subject).not_to have_selector("img[src*='base-single']")
  end
end

RSpec.shared_examples :has_base_single do
  it 'includes a base-single img' do
    expect(subject).to have_selector("img[src*='base-single']")
  end
end

RSpec.shared_examples :has_remote_link do
  it 'builds a remote link' do
    expect(subject).to have_selector("a[data-remote]")
    expect(subject).to have_selector("a[data-method='post']")
  end
end

RSpec.shared_examples :has_sparkle_link do
  it 'builds a sparkle link' do
    expect(subject).to have_selector("a[data-miq_sparkle_on]")
    expect(subject).to have_selector("a[data-miq_sparkle_off]")
  end
end

RSpec.shared_examples :storage_inferred_url do
  it 'links to an inferred url' do
    expect(subject).to have_selector("a[href^='/storage/show']")
  end
end

RSpec.shared_examples :storage_name_type_title do
  it 'has a title with name and type' do
    expect(subject).to include("Name: #{item.name} | Datastore Type: VMFS")
  end
end

RSpec.shared_examples :vm_or_template_vendor do
  it 'includes a vendor icon' do
    expect(subject).to have_selector("img[src*='vendor-openstack']")
  end
end

RSpec.shared_examples :vm_or_template_compliance do
  # FIXME: only one possibility covered
  it 'includes image for compliance' do
    allow(item).to receive(:passes_profiles?) { true }
    expect(subject).to have_selector("img[src*='check']")
  end
end

RSpec.shared_examples :has_name_in_title_attr do
  it 'has a title attribute equal to the name' do
    expect(subject).to have_selector("img[title='#{item.name}']")
  end
end

# FIXME: complex describe blocks mirror the existing complex control flow

describe QuadiconHelper do
  describe "#render_quadicon" do
    context "when vm_or_template" do
      subject { helper.render_quadicon(item) }

      let(:item) do
        FactoryGirl.build(:vm_vmware) # => ManageIQ::Providers::Vmware::InfraManager::Vm.name)
      end

      it "renders quadicon for a vmware vm" do
        expect(subject).to have_selector('div.quadicon')
        expect(subject).to have_selector('div.quadicon div.flobj')
      end

      it "has an id that matches the item" do
        expect(subject).to have_selector("#quadicon_#{item.id}")
      end
    end

    context "when type is listnav" do
      let(:item) { FactoryGirl.build(:vm_vmware) }
      let(:options) { {:typ => :listnav} }
      subject(:listnav_quad) { helper.render_quadicon(item, options) }

      it 'includes inline styles' do
        expect(listnav_quad).to include('style="margin-left: auto;')
      end

      it 'does not have quadicon class' do
        expect(listnav_quad).not_to have_selector("div.quadicon")
      end
    end

    context "when storage-related objects" do
      before(:each) do
        helper.instance_variable_set(:@view, FactoryGirl.build(:miq_report))
      end

      %w(
        cim_storage_extent
        ontap_file_share
        ontap_logical_disk
        ontap_storage_system
        ontap_storage_volume
        snia_local_file_system
      ).each do |obj|
        it "renders a quadicon for #{obj}" do
          item = FactoryGirl.create(obj, :obj => WBEM::CIMInstance.new("ONTAP_StorageSystem"))
          subject = helper.render_quadicon(item, :mode => :icon)

          expect(subject).to have_selector('div.quadicon')
        end
      end

      # It seems as though Quadicons are no longer generated for this type,
      # but it's in the list, so with a little cheating ...
      it "renders a quadicon for CimBaseStorageExtent" do
        item = CimBaseStorageExtent.new

        allow(item).to receive(:name) { 'cim_base_storage_extent' }
        allow(helper).to receive(:restful_routed?) { false }
        allow(helper).to receive(:url_for_db) { "/vm_infra" }

        subject = helper.render_quadicon(item, :mode => :icon)

        expect(subject).to have_selector('div.quadicon')
      end
    end

    context "when service related objects" do
      before(:each) do
        allow(controller).to receive(:default_url_options) do
          {:controller => "vm_infra"}
        end
      end

      %w(
        service
        service_template
        service_ansible_tower
        service_template_ansible_tower
      ).each do |obj|
        it "renders a quadicon for #{obj}" do
          item = FactoryGirl.create(obj)
          subject = helper.render_quadicon(item, :mode => :icon)

          expect(subject).to have_selector('div.quadicon')
        end
      end
    end

    context "when resource_pool" do
      let(:item) { FactoryGirl.create(:resource_pool) }
      subject { helper.render_quadicon(item, :mode => :icon) }

      it 'renders a quadicon for a resource_pool' do
        expect(subject).to have_selector('div.quadicon')
        expect(subject).to have_selector('[src*="resource_pool"]')
      end
    end

    context "when host" do
      let(:item) { FactoryGirl.create(:host) }
      subject { helper.render_quadicon(item, :mode => :icon) }

      include_examples :quadicon_with_link

      it 'renders a quadicon without a link with listnav option' do
        quadicon = helper.render_quadicon(item, :mode => :icon, :typ => :listnav)
        expect(quadicon).to_not have_selector('a')
      end
    end

    context "when ext_management_system" do
      let(:item) { FactoryGirl.create(:ems_redhat) }
      subject { helper.render_quadicon(item, :mode => :icon) }

      include_examples :quadicon_with_link
    end

    context "when ems_cluster" do
      let(:item) { FactoryGirl.create(:ems_cluster) }
      subject { helper.render_quadicon(item, :mode => :icon) }

      include_examples :quadicon_with_link
    end

    context "when single_quad" do
      before(:each) do
        @embedded = false
        @explorer = true
        allow(controller).to receive(:list_row_id).with(item) do
          ApplicationRecord.compress_id(item.id)
        end
        allow(controller).to receive(:default_url_options) do
          {:controller => "provider_foreman"}
        end
      end

      let(:item) { FactoryGirl.create(:configuration_manager_foreman) }
      subject { helper.render_quadicon(item, :mode => :icon) }

      include_examples :quadicon_with_link
    end

    context "when storage" do
      let(:item) { FactoryGirl.create(:storage) }
      subject { helper.render_quadicon(item, :mode => :icon) }

      include_examples :quadicon_with_link
    end

    context "when vm_or_template" do
      let(:item) { FactoryGirl.create(:vm_or_template) }
      subject { helper.render_quadicon(item, :mode => :icon) }

      include_examples :quadicon_with_link
    end
  end

  describe "#render_quadicon_text" do
    before(:each) do
      @settings = {:display => {:quad_truncate => "m"}}
    end

    let(:item) do
      FactoryGirl.build(:vm_vmware)
    end

    let(:row) do
      Ruport::Data::Record.new(:id => rand(999_999_999), "name" => "Baz")
    end

    it "returns nil if no item" do
      expect(helper.render_quadicon_text(nil, nil)).to be(nil)
    end

    context "when @embedded is defined" do
      before(:each) do
        @embedded = true
      end

      let(:cim) do
        FactoryGirl.build(:miq_cim_instance)
      end

      let(:cim_row) do
        Ruport::Data::Record.new(:id => rand(9999), "evm_display_name" => "Foo")
      end

      let(:sys) do
        FactoryGirl.build(:configured_system)
      end

      let(:sys_row) do
        Ruport::Data::Record.new(:id => rand(9999), "hostname" => "Bar")
      end

      it "renders a span tag with truncated text" do
        expect(helper.render_quadicon_text(cim, cim_row)).to include("Foo")
        expect(helper.render_quadicon_text(sys, sys_row)).to include("Bar")
        expect(helper.render_quadicon_text(item, row)).to include("Baz")
      end

      it "renders a link when @showlinks is true" do
        @showlinks = true
        expect(helper.render_quadicon_text(item, row)).to have_selector('a')
      end
    end

    # NOTE: the @listicon branch seems to be unused after asking team, skipped testing
    # NOTE: the @policy_sim branch seems to me to be unused, but tried testing

    context "when @policy_sim and session[:policies]", :unused => true do
      it "renders a link with a specific title" do
        @policy_sim = true
        session[:policies] = ["thing"]

        expect(helper.render_quadicon_text(item, row)).to include("Show policy details")
      end
    end

    context "when item is an EmsCluster" do
      let(:ems) do
        FactoryGirl.build(:ems_cluster)
      end

      let(:row) do
        Ruport::Data::Record.new(
          "id"               => rand(999),
          "v_qualified_desc" => "My Ems Cluster description"
        )
      end

      subject { helper.render_quadicon_text(ems, row) }

      it "renders a link with the v_qualified_desc" do
        expect(subject).to include("My Em...")
        expect(subject).to include("/ems_cluster/show")
      end
    end

    context "when item is a EmsContainer" do
      let(:ems) do
        FactoryGirl.create(:ems_container, :name => "Ems Container")
      end

      subject { helper.render_quadicon_text(ems, row) }

      it "renders a link to ems_container" do
        @id = ems.id

        expect(subject).to have_selector('a')
        expect(subject).to include("/ems_container/#{@id}")
      end
    end

    context "when item is a StorageManager" do
      let(:stor) do
        FactoryGirl.create(:storage_manager, :name => "Store Man")
      end

      subject { helper.render_quadicon_text(stor, row) }

      it "renders a link to storage_manager" do
        @id = stor.id

        expect(subject).to have_selector('a')
        expect(subject).to include("/storage_manager/show/#{@id}")
      end
    end

    context "when item is a FloatingIP" do
      let(:item) do
        FactoryGirl.create(:floating_ip_openstack)
      end

      let(:row) { Ruport::Data::Record.new(:id => rand(9999)) }

      subject { helper.render_quadicon_text(item, row) }

      it "renders a label based on the address" do
        @id = item.id

        expect(subject).to have_link(item.address)
        expect(subject).to include("/floating_ip/show/#{item.id}")
      end
    end

    context "when item is an Authentication" do
      let(:item) do
        FactoryGirl.create(:authentication)
      end

      let(:row) do
        Ruport::Data::Record.new(:id => rand(999), "name" => "Auth")
      end

      subject { helper.render_quadicon_text(item, row) }

      it 'renders a link with auth_key_pair_cloud path' do
        expect(subject).to have_link("Auth")
        expect(subject).to include('href="/auth_key_pair_cloud/show"')
      end
    end

    context "when @explorer is defined" do
      before(:each) do
        @explorer = true
        @id = vm.id

        allow(controller).to receive(:default_url_options) do
          {:controller => "vm_infra"}
        end
        allow(controller).to receive(:controller_name).and_return("service")
      end

      let(:serv_res) do
        FactoryGirl.build(:service_resource)
      end

      let(:conf_sys) do
        FactoryGirl.build(:configured_system)
      end

      let(:conf_profile) do
        FactoryGirl.build(:configuration_profile)
      end

      let(:vm) do
        FactoryGirl.create(:vm_vmware)
      end

      let(:row) do
        Ruport::Data::Record.new(
          "id"            => rand(9999),
          "name"          => "Fred",
          "resource_name" => "Service Res",
          "hostname"      => "Conf System",
          "description"   => "Conf Profile"
        )
      end

      subject { helper.render_quadicon_text(vm, row) }

      context "when controller is service and view.db is Vm" do
        before(:each) do
          # assigning @view here conflicts with rspec, so we set it inside helper:
          helper.instance_variable_set(:@view, FactoryGirl.build(:miq_report))
          helper.request.parameters[:controller] = "service"
        end

        it "renders a sparkle link for Vms, role permitting" do
          allow(helper).to receive(:role_allows?) { true }

          expect(subject).to include("Fred")
          expect(subject).to include("/vm_infra/show/#{vm.id}")
          expect(subject).to have_selector("[data-miq_sparkle_on]")
          expect(subject).to have_selector("[data-miq_sparkle_off]")
          expect(subject).not_to have_selector("[data-remote]")
        end

        it "renders a link from inferred url_options for ServiceResources" do
          subject = helper.render_quadicon_text(serv_res, row)

          expect(subject).to include("Service Res")
          expect(subject).to have_selector('a')
          expect(subject).not_to have_selector("[data-miq_sparkle_on]")
        end

        it "renders a link from inferred url_options for Vms, with insufficent permissions" do
          expect(subject).to include("Fred")
          expect(subject).not_to have_selector("[data-miq_sparkle_on]")
        end
      end

      context "when controller is not service or view.db is not Vm" do
        before(:each) do
          allow(controller).to receive(:list_row_id).with(row) do
            ApplicationRecord.compress_id(vm.id)
          end
        end

        include_examples :has_sparkle_link

        it 'renders a post link with sparkle and remote attributes' do
          expect(subject).to include("Fred")
          expect(subject).to have_selector("[data-remote]")
          expect(subject).to have_selector("[data-method='post']")
        end
      end
    end

    context "default case" do
      before(:each) do
        @id = item.id
      end

      let(:item) do
        FactoryGirl.create(:vm_vmware)
      end

      it "renders the full name in the title tag" do
        long_name = "A really long truncatable name"
        row.name = long_name
        label = helper.render_quadicon_text(item, row)
        expect(label).to match(/title=\"#{long_name}\"/)
      end

      it 'renders a link with the row evm_display_name if set' do
        row = Ruport::Data::Record.new(
          "id"               => rand(9999),
          "evm_display_name" => "evm"
        )

        subject = helper.render_quadicon_text(item, row)

        expect(subject).to include("evm")
        expect(subject).to include("/vm/show/#{item.id}")
      end

      it 'renders a link with the row key if set' do
        row = Ruport::Data::Record.new(
          :id   => rand(9999),
          "key" => "key"
        )

        expect(helper.render_quadicon_text(item, row)).to include("key")
      end

      it 'renders a link with the row name if set' do
        row = Ruport::Data::Record.new(:id => rand(9999), "name" => "name")

        subject = helper.render_quadicon_text(item, row)

        expect(subject).to include("name")
        expect(subject).to include("/vm/show/#{item.id}")
      end
    end
  end

  it 'determines if in embedded view' do
    @embedded = true

    expect(helper.quadicon_in_embedded_view?).to be(true)
  end

  describe "#render_quadicon_label" do
    before(:each) do
      @settings = {:display => {:quad_truncate => "m"}}
    end

    subject { helper.render_quadicon_label(item, row) }

    let(:item) do
      FactoryGirl.build(:vm_vmware)
    end

    let(:row) do
      Ruport::Data::Record.new(:id => rand(9999), "name" => "Baz")
    end

    context "when in embedded view" do
      it 'renders a span tag' do
        @embedded = true
        @showlinks = false

        expect(subject).to have_selector('span')
      end

      it 'has no links when @quadicon_no_url is true' do
        @quadicon_no_url = true
        @embedded = true
        @showlinks = false
        expect(subject).not_to include('href')
      end
    end

    context "when not in embedded view" do
      it 'renders a span tag' do
        @embedded = false

        expect(subject).to have_selector('a')
      end
    end
  end

  describe "#quadicon_label_content" do
    before(:each) do
      @settings = {:display => {:quad_truncate => "m"}}
    end

    it 'returns the row hostname for ConfiguredSystems' do
      item = FactoryGirl.build(:configured_system)
      row = Ruport::Data::Record.new('id' => rand(999_999_999), 'hostname' => 'Bar')

      expect(helper.quadicon_label_content(item, row)).to eq("Bar")
    end
  end

  describe "#quadicon_model_name" do
    it 'returns ConfiguredSystem when object is a ConfiguredSystem' do
      item = FactoryGirl.build(:configured_system)
      expect(helper.quadicon_model_name(item)).to eq("ConfiguredSystem")
    end
  end

  describe "#quadicon_build_label_options" do
    before(:each) do
      @settings = {:display => {:quad_truncate => "m"}}
    end

    let(:item) do
      FactoryGirl.build(:vm_vmware)
    end

    let(:row) do
      Ruport::Data::Record.new(:id => rand(999_999_999), "name" => "Baz")
    end

    subject { helper.quadicon_build_label_options(item, row) }

    it 'Sets the title for policies' do
      @policy_sim = true
      session[:policies] = ["thing"]

      expect(subject[:options]).to have_key(:title)
      expect(subject[:options][:title]).to eq("Show policy details for #{row['name']}")
    end
  end

  describe "truncating text for quad icons" do
    it 'truncates from the front' do
      text = helper.truncate_for_quad("ABCDEooo12345", :mode => 'f')
      expect(text).to eq("...DEooo12345")
    end

    it 'truncates from the back' do
      text = helper.truncate_for_quad("ABCDEooo12345", :mode => 'b')
      expect(text).to eq("ABCDEooo12...")
    end

    it 'truncates the middle by default' do
      text = helper.truncate_for_quad("ABCDEooo12345")
      expect(text).to eq("ABCDE...12345")
    end

    it "when value is nil" do
      text = helper.truncate_for_quad(nil)
      expect(text).to be_empty
    end

    it "when value is < 13 long" do
      text = helper.truncate_for_quad("Test")
      expect(text).to eq("Test")
    end

    it "when value is 12 long" do
      text = helper.truncate_for_quad("ABCDEFGHIJKL")
      expect(text).to eq("ABCDEFGHIJKL")
    end
  end

  describe "#flobj_img_simple" do
    subject { helper.flobj_img_simple("100") }

    it 'returns an image wrapped in a div' do
      expect(subject).to have_selector("img")
      expect(subject).to have_selector("div.flobj")
      expect(subject).to include("100")
    end
  end

  describe "#render_ext_management_system_quadicon" do
    before(:each) do
      @settings = {:quadicons => {:ems => true}}
      allow(item).to receive(:hosts).and_return(%w(foo bar))
      allow(item).to receive(:image_name).and_return("foo")
      @layout = "ems_infra"
    end

    let(:item) { FactoryGirl.build(:ems_infra) }
    let(:options) { {:size => 72, :type => 'grid'} }
    subject(:ext_quad) { helper.render_ext_management_system_quadicon(item, options) }

    it "doesn't display IP Address in the tooltip" do
      expect(ext_quad).not_to match(/IP Address/)
    end

    it "displays Host Name in the tooltip" do
      expect(ext_quad).to match(/Hostname/)
    end

    context "when type is not listicon" do
      let(:item) { FactoryGirl.create(:ems_infra) }

      it 'links to the record (with full id)' do
        expect(subject).to have_selector("a[href*='ems_infra/#{item.id}']")
      end
    end
  end

  describe "#render_service_quadicon" do
    let(:options) { {:size => 72, :type => 'grid'} }
    let(:item) { FactoryGirl.build(:service, :id => 100) }
    subject(:service_quad) { helper.render_service_quadicon(item, options) }

    context "for service w/o custom picture" do
      it "renders quadicon" do
        allow(helper).to receive(:url_for).and_return("/path")

        expect(service_quad).to have_selector('div.flobj', :count => 2)
        expect(service_quad).to match(/service-[\w]*.png/)
      end
    end

    context "for service w/ custom picture" do
      before(:each) do
        allow(item).to receive(:picture) { Pathname.new('/boo/foobar.png') }
      end

      it "renders quadicon" do
        allow(helper).to receive(:url_for).and_return("/path")

        expect(service_quad).to have_selector('div.flobj', :count => 2)
        expect(service_quad).to match(/foobar.png/)
      end
    end

    context "for Orchestration Template Catalog Item w/o custom picture" do
      let(:item) { FactoryGirl.build(:service_template_orchestration) }

      it "renders" do
        allow(helper).to receive(:url_for).and_return("/path")

        expect(service_quad).to have_selector('div.flobj', :count => 2)
        expect(service_quad).to match(/service_template-[\w]*.png/)
      end
    end

    context "when not embedded" do
      before(:each) do
        @embedded = false
        allow(controller).to receive(:default_url_options) do
          {:controller => "service", :action => "show"}
        end
      end

      include_examples :has_sparkle_link
    end
  end

  describe "#render_resource_pool_quadicon" do
    let(:item) { FactoryGirl.create(:resource_pool) }
    let(:options) { {:mode => :icon} }
    subject(:quadicon) { helper.render_resource_pool_quadicon(item, options) }

    include_examples :shield_img_with_policies

    it 'has a vapp image when vapp' do
      item.vapp = true

      expect(subject).to have_selector('img[src*="vapp"]')
    end

    context "when type is not listnav" do
      it 'has a link to nowhere when embedded' do
        @embedded = true

        expect(subject).to have_selector("a")
        expect(subject).to include('href=""')
      end

      it 'links to the item when not embedded' do
        @embedded = false
        cid = ApplicationRecord.compress_id(item.id)
        expect(subject).to have_selector("a[href*='resource_pool/show/#{cid}']")
      end
    end

    context "when type is listnav" do
      include_examples :no_link_for_listnav
    end
  end

  describe "#render_host_quadicon" do
    let(:item) { FactoryGirl.create(:host) }
    let(:options) { {:mode => :icon, :size => 72} }
    subject(:host_quad) { helper.render_host_quadicon(item, options) }

    context "when @settings includes :quadicon => :host" do
      before(:each) do
        @settings = {:quadicons => {:host => true}}
      end

      it 'renders a quadicon with the base img' do
        expect(host_quad).to have_selector("img[src*='base']")
      end

      it 'renders a quadicon with a paragraph containing the vm count' do
        expect(host_quad).to have_selector("p")
        expect(host_quad).to include("0")
      end

      it 'renders a quadicon with a state img' do
        expect(host_quad).to have_selector("img[src*='currentstate-archived']")
      end

      include_examples :host_vendor_icon, "c"

      it 'renders a quadicon with an auth status img' do
        expect(host_quad).to have_selector("img[src*='unknown']")
      end

      include_examples :shield_img_with_policies
    end

    context "when no :quadicon in @settings" do
      include_examples :host_vendor_icon, "e"
    end

    context "when type is listnav" do
      include_examples :no_link_for_listnav
      include_examples :has_reflection
    end

    context "when type is not listnav" do
      context "when not embedded or showlinks" do
        before(:each) do
          @embedded = false
        end

        it 'links to /host/edit when @edit[:hostnames] is present' do
          @edit = {:hostitems => true}
          expect(host_quad).to have_selector("a[href^='/host/edit']")
        end

        it 'links to the record with no @edit' do
          @edit = nil
          cid = ApplicationRecord.compress_id(item.id)
          expect(host_quad).to have_selector("a[href^='/host/show/#{cid}']")
        end
      end

      context "when embedded" do
        before(:each) do
          @embedded = true
          allow(controller).to receive(:default_url_options) do
            {:controller => "host", :action => "show"}
          end
        end

        it 'links to an inferred url' do
          expect(host_quad).to have_selector("a[href^='/host/show']")
        end
      end
    end
  end

  describe "#render_ems_cluster_quadicon" do
    let(:item) { FactoryGirl.create(:ems_cluster) }
    let(:options) { {:mode => :icon, :size => 72} }
    subject(:ems_cluster_quad) { helper.render_ems_cluster_quadicon(item, options) }

    include_examples :has_base_single

    it 'includes an ems-cluster img' do
      expect(ems_cluster_quad).to have_selector("img[src*='emscluster']")
    end

    context "when type not is listnav" do
      include_examples :has_reflection

      context "when not embedded or showlinks" do
        before(:each) do
          @embedded  = false
          @showlinks = false
        end

        it 'links to the record' do
          cid = ApplicationRecord.compress_id(item.id)
          expect(ems_cluster_quad).to have_selector("a[href^='/ems_cluster/show/#{cid}']")
        end
      end

      context "when embedded" do
        before(:each) do
          @embedded = true
          allow(controller).to receive(:default_url_options) do
            {:controller => "ems_cluster", :action => "show"}
          end
        end

        it 'links to an inferred url' do
          expect(ems_cluster_quad).to have_selector("a[href^='/ems_cluster/show']")
        end
      end
    end
  end

  describe "#render_single_quad_quadicon" do
    before(:each) do
      @embedded = false
      @explorer = true
      allow(controller).to receive(:list_row_id).with(item) do
        ApplicationRecord.compress_id(item.id)
      end
      allow(controller).to receive(:default_url_options) do
        {:controller => "provider_foreman"}
      end
    end

    let(:item) { FactoryGirl.create(:configuration_manager_foreman) }
    subject(:single_quad) { helper.render_single_quad_quadicon(item, :mode => :icon, :size => 72) }

    context "when @listicon is nil" do
      include_examples :has_base_single

      context "when item is MiqCimInstance" do
        let(:item) do
          obj = WBEM::CIMInstance.new("ONTAP_StorageSystem")
          obj["Name"] = "FooBar"

          FactoryGirl.create(:miq_cim_instance, :obj => obj)
        end

        it 'includes a miq_cim_instance img' do
          expect(single_quad).to have_selector("img[src*='miq_cim_instance']")
        end

        it 'is named after the evm_display_name' do
          expect(single_quad).to include(item.evm_display_name)
        end
      end

      context "when item is CimStorageExtent" do
        let(:item) do
          obj = WBEM::CIMInstance.new("ONTAP_StorageSystem")
          FactoryGirl.create(:cim_storage_extent, :obj => obj)
        end

        it 'includes a cim_base_storage_extent img' do
          expect(single_quad).to have_selector("img[src*='cim_base_storage_extent']")
        end
      end

      context "when item is decorated" do
        context "when item is a config manager foreman" do
          it 'includes a vendor listicon img' do
            expect(single_quad).to have_selector("img[src*='vendor-#{item.image_name}']")
          end
        end

        context "when item is a middleware deployment" do
          let(:item) { FactoryGirl.create(:middleware_deployment) }

          it 'includes a vendor listicon img' do
            expect(single_quad).to have_selector("img[src*='middleware_deployment']")
          end
        end
      end

      context "when item is not CIM or decorated" do
        before(:each) do
          allow(item).to receive(:decorator_class?) { false }
        end

        it "includes an image with the item's base class name" do
          name = item.class.base_class.to_s.underscore
          expect(single_quad).to have_selector("img[src*='#{name}']")
        end
      end

      context "when type is not :listnav" do
        it 'includes a flobj div' do
          expect(single_quad).to have_selector("div.flobj")
        end

        context "when not embedded" do
          context "when explorer" do
            before(:each) do
              @explorer = true
            end

            include_examples :has_sparkle_link

            it 'links to x_show with compressed id' do
              cid = ApplicationRecord.compress_id(item.id)
              expect(subject).to have_selector("a[href*='x_show/#{cid}']")
            end
          end

          context "when not explorer" do
            it 'links to the record' do
              cid = ApplicationRecord.compress_id(item.id)
              expect(subject).to have_selector("a[href*='#{cid}']")
            end
          end
        end

        context "when embedded" do
          before(:each) do
            @embedded = true
          end

          it 'links to nowhere' do
            expect(single_quad).to have_selector("a[href='']")
          end
        end
      end
    end # => when @listicon is nil

    context "when listicon is not nil" do
      before(:each) do
        @listicon = "foo"
        @parent = FactoryGirl.build(:vm_vmware)
      end

      include_examples :has_base_single

      it 'includes a listicon image' do
        expect(single_quad).to have_selector("img[src*='foo']")
      end

      context "when listicon is scan_history" do
        let(:item) { ScanHistory.new(:started_on => Time.zone.today) }

        before(:each) do
          @listicon = "scan_history"
        end

        it 'titles based on the item started_on' do
          expect(single_quad).to include("title=\"#{item.started_on}\"")
        end
      end

      context "when listicon is orchestration_stack_output" do
        let(:item) { OrchestrationStackOutput.new(:key => "Bar") }

        before(:each) do
          @listicon = "orchestration_stack_output"
        end

        it 'titles based on the item key' do
          expect(single_quad).to include("title=\"Bar\"")
        end
      end
    end
  end

  describe "#render_storage_quadicon" do
    let(:item) do
      FactoryGirl.create(
        :storage,
        :store_type  => "VMFS",
        :total_space => 1000,
        :free_space  => 250
      )
    end

    let(:options) { {:mode => :icon, :size => 72, :db => "Storage"} }

    subject(:storage_quad) { helper.render_storage_quadicon(item, options) }

    context "when @settings includes :quadicon => :storage" do
      before(:each) do
        @settings = {:quadicons => {:storage => true}}
      end

      it 'shows free space' do
        expect(storage_quad).to include("5")
      end

      it 'includes the base img' do
        expect(storage_quad).to have_selector("img[src*='base']")
        expect(storage_quad).not_to have_selector("img[src*='base-single']")
      end

      it 'shows a count of vms' do
        allow(item).to receive(:v_total_vms) { 7 }
        expect(storage_quad).to include('<div class="flobj b72"><p>7</p>')
      end

      it 'shows a count of hosts' do
        allow(item).to receive(:v_total_hosts) { 4 }
        expect(storage_quad).to include('<div class="flobj c72"><p>4</p>')
      end
    end

    context "when @settings does not include :storage" do
      it 'shows used space' do
        expect(storage_quad).to have_selector("img[src*='datastore-8']")
      end

      it 'includes the base-single img' do
        expect(storage_quad).to have_selector("img[src*='base-single']")
      end
    end

    context "when type is :listnav" do
      let(:options) { {:typ => :listnav} }

      include_examples :has_reflection
      include_examples :no_link_for_listnav
    end

    context "when type is not :listnav" do
      context "when explorer" do
        before(:each) do
          @explorer = true
        end

        context "and not embedded" do
          before(:each) do
            @embedded = false
            allow(controller).to receive(:default_url_options) do
              {:controller => "storage"}
            end
          end

          include_examples :has_reflection
          include_examples :has_sparkle_link

          it 'links to the record' do
            cid = ApplicationRecord.compress_id(item.id)
            expect(storage_quad).to have_selector("a[href*='x_show/#{cid}']")
          end
        end

        context "and embedded" do
          before(:each) do
            @embedded = true
            allow(controller).to receive(:default_url_options) do
              {:controller => "storage", :action => "show"}
            end
          end

          include_examples :has_reflection
          include_examples :storage_inferred_url
          include_examples :storage_name_type_title
        end
      end

      context "when not explorer" do
        before(:each) do
          @explorer = false
        end

        include_examples :has_reflection

        context "and not embedded" do
          before(:each) do
            @embedded = false
          end

          it 'links to the record' do
            cid = ApplicationRecord.compress_id(item.id)
            expect(storage_quad).to have_selector("a[href^='/storage/show/#{cid}']")
          end

          include_examples :has_reflection
          include_examples :storage_name_type_title
        end

        context "and embedded" do
          before(:each) do
            @embedded = true
            allow(controller).to receive(:default_url_options) do
              {:controller => "storage", :action => "show"}
            end
          end

          include_examples :storage_inferred_url
          include_examples :has_reflection
          include_examples :storage_name_type_title
        end
      end
    end
  end

  describe "#render_vm_or_template_quadicon" do
    let(:item) { FactoryGirl.create(:vm_or_template, :vendor => "openstack") }
    let(:options) { {:mode => :icon, :size => 72} }
    subject(:vm_quad) { helper.render_vm_or_template_quadicon(item, options) }

    context "when settings includes item base class name" do
      before(:each) do
        @settings = {:quadicons => {:vm_or_template => true}}
      end

      include_examples :has_base_img
      include_examples :shield_img_with_policies
      include_examples :vm_or_template_vendor

      it 'includes an os image' do
        expect(vm_quad).to have_selector("img[src*='os-unknown']")
      end

      it 'includes a state image' do
        expect(vm_quad).to have_selector("img[src*='currentstate-archived']")
      end

      context "when lastaction is policy_sim" do
        before(:each) do
          @lastaction = "policy_sim"
        end

        context "and @policy_sim is present and session policies is not empty" do
          before(:each) do
            @policy_sim = true
            session[:policies] = {:foo => :bar}
          end

          include_examples :vm_or_template_compliance
        end
      end

      context "when lastaction is not policy_sim" do
        before(:each) do
          @lastaction = "foo"
        end

        it 'includes the total snapshot count' do
          allow(item).to receive(:v_total_snapshots) { 9 }
          expect(vm_quad).to include('<div class="flobj d72"><p>9</p>')
        end
      end
    end

    context "when settings does not include item base class name" do
      include_examples :has_base_single
      include_examples :vm_or_template_vendor

      # @policy_sim && !session[:policies].empty?
      context "when @policy_sim is truthy and when session policies is not empty" do
        before(:each) do
          @policy_sim = true
          session[:policies] = {:foo => :bar}
        end

        include_examples :vm_or_template_compliance
      end
    end

    context "when type is not listnav" do
      before(:each) do
        allow(controller).to receive(:default_url_options) do
          {:controller => "vm_infra"}
        end
      end

      let(:options) { {:mode => :icon, :size => 72, :type => "foo"} }

      include_examples :has_reflection

      context "when not embedded" do
        before(:each) do
          @embedded = false
        end

        context "when in explorer view" do
          before(:each) do
            @explorer = true
          end

          include_examples :has_sparkle_link

          context "when service controller and Vm view" do
            before(:each) do
              # assigning @view here conflicts with rspec, so we set it inside helper:
              helper.instance_variable_set(:@view, FactoryGirl.build(:miq_report))
              helper.request.parameters[:controller] = "service"
            end

            include_examples :has_name_in_title_attr

            it 'does not build a remote link' do
              expect(vm_quad).not_to have_selector("a[data-remote]")
              expect(vm_quad).not_to have_selector("a[data-method='post']")
            end

            context "and when url can be found with vm_quad_link_attributes" do
              before(:each) do
                allow(helper).to receive(:role_allows?) { true }
                allow(helper).to receive(:vm_quad_link_attributes) do
                  {
                    :link       => true,
                    :controller => "vm_infra",
                    :action     => "show",
                    :id         => item.id
                  }
                end
              end

              include_examples :has_sparkle_link

              it 'builds the link based on attributes' do
                expect(vm_quad).to have_selector("a[href^='/vm_infra']")
              end
            end

            context "and when url cannot be found with vm_quad_link_attributes" do
              it 'links to nowhere' do
                expect(vm_quad).to have_selector("a[href='']")
              end
            end
          end

          context "when not in service controller" do
            before(:each) do
              # because quadicon_vm_attributes_present? can be true
              allow(helper).to receive(:vm_quad_link_attributes) do
                {
                  :link       => true,
                  :controller => "vm_infra",
                  :action     => "show",
                  :id         => item.id
                }
              end
            end

            it 'links to x_show' do
              cid = ApplicationRecord.compress_id(item.id)
              expect(vm_quad).to have_selector("a[href*='x_show/#{cid}']")
            end

            include_examples :has_remote_link
            include_examples :has_name_in_title_attr
          end
        end

        context "when not in explorer view" do
          before(:each) do
            @explorer = false
          end

          include_examples :has_name_in_title_attr

          it 'links to the record' do
            expect(vm_quad).to have_selector("a[href^='/vm_or_template/show']")
          end
        end
      end

      context "when embedded" do
        before(:each) do
          @embedded = true
          @showlinks = false
          @explorer = false
        end

        context "when @policy_sim" do
          before(:each) do
            @policy_sim = true
            session[:policies] = {:foo => :bar}
            allow(item).to receive(:passes_profiles?) { true }
          end

          context "and when @edit[:explorer]" do
            before(:each) do
              @edit = {:explorer => true}
            end

            include_examples :has_remote_link
            include_examples :has_sparkle_link
            include_examples :has_name_in_title_attr
          end

          context "and when @edit or @edit[:explorer] is not present" do
            it 'includes a policy detail title attribute' do
              expect(subject).to include("Show policy details for")
            end

            it 'links to policies action with cid' do
              cid = ApplicationRecord.compress_id(item.id)
              expect(subject).to have_selector("a[href*='policies/#{cid}']")
            end
          end
        end

        context "when @policy_sim is falsey" do
          before(:each) do
            @policy_sim = false
            allow(controller).to receive(:default_url_options) do
              {:controller => "vm_or_template", :action => "show"}
            end
          end

          it 'links to an inferred url' do
            expect(vm_quad).to have_selector("a[href^='/vm_or_template/show']")
          end

          include_examples :has_name_in_title_attr
        end
      end
    end

    context "when type is listnav" do
      include_examples :no_link_for_listnav
    end
  end
end
