require 'spec_helper'
require 'wbem'

describe QuadiconHelper do
  describe "#render_quadicon" do
    subject { helper.render_quadicon(item, {}) }

    let(:item) do
      FactoryGirl.create(:vm_vmware)#, :type => ManageIQ::Providers::Vmware::InfraManager::Vm.name)
    end

    it "renders quadicon for a vmware vm" do
      expect(subject).to have_selector('div.quadicon')
      expect(subject).to have_selector('div.quadicon div.flobj')
    end
  end

  #FIXME: this complex describe block mirrors the complex method

  describe "#render_quadicon_text" do
    before(:each) do
      @settings = {:display => {:quad_truncate => "m"}}
    end

    it "returns nil if no item" do
      expect( helper.render_quadicon_text(nil, nil) ).to be(nil)
    end

    context "when @embedded is defined" do
      before(:each) do
        @embedded = true
      end

      let(:cim) { FactoryGirl.create(:miq_cim_instance) }

      let(:cim_row) do
        Ruport::Data::Record.new(:id => 111, "evm_display_name" => "Foo")
      end

      let(:sys) do
        FactoryGirl.create(:configured_system)
      end

      let(:sys_row) do
        Ruport::Data::Record.new(:id => 113, "hostname" => "Bar")
      end

      let(:item) do
        FactoryGirl.create(:vm_vmware)
      end

      let(:row) do
        Ruport::Data::Record.new(:id => 115, "name" => "Baz")
      end

      it "renders a span tag with truncated text" do
        # when "MiqCimInstance"   then 'evm_display_name'
        # when "ConfiguredSystem" then 'hostname'
        # else 'name'

        expect( helper.render_quadicon_text(cim, cim_row) ).to include("Foo")
        expect( helper.render_quadicon_text(sys, sys_row) ).to include("Bar")
        expect( helper.render_quadicon_text(item, row) ).to include("Baz")
      end

      it "renders a link when @showlinks is true" do
        @showlinks = true
        expect( helper.render_quadicon_text(item, row) ).to have_selector('a')
      end
    end

    context "when @listicon is defined" do

    end

    context "when @policy_sim is defined" do

    end

    context "when item is an EmsCluster" do
      let(:item) do
        FactoryGirl.create(:ems_cluster)
      end

      let(:row) do
        Ruport::Data::Record.new(
          :id => rand(999),
          "v_qualified_desc" => "My Ems Cluster description"
        )
      end

      it "renders a link with the v_qualified_desc" do
        expect( helper.render_quadicon_text(item, row) ).to include("description")
      end
    end

    context "when item is a StorageManager" do
      let(:item) do
        FactoryGirl.create(:storage_manager, :name => "Store Man")
      end

      let(:row) do
        Ruport::Data::Record.new(:id => rand(999), "name" => "My StorageManager")
      end

      subject { helper.render_quadicon_text(item, row) }

      it "renders a link to storage_manager" do
        @id = item.id

        expect(subject).to have_selector('a')
        expect(subject).to have_selector("a[href=\"/storage_manager/show/#{@id}\"]")
      end
    end

    context "when item is a FloatingIP" do
      let(:item) do
        FactoryGirl.create(:floating_ip_openstack)
      end

      let(:row) { Ruport::Data::Record.new(:id => 115) }

      subject{ helper.render_quadicon_text(item, row) }

      it "renders a label based on the address" do
        expect(subject).to have_link(item.address)
      end
    end

    context "when @explorer is defined" do
      before(:each) do
        @explorer = true
      end

      let(:serv_res) do
        FactoryGirl.create(:service_resource)
      end

      let(:conf_sys) do
        FactoryGirl.create(:configured_system)
      end

      let(:conf_profile) do
        FactoryGirl.create(:configuration_profile)
      end

      let(:vm) do
        FactoryGirl.create(:vm_vmware)
      end

      let(:row) do
        Ruport::Data::Record.new(
          :id => rand(999),
          "name" => "Fred",
          "resource_name" => "Service Res",
          "hostname" => "Conf System",
          "description" => "Conf Profile"
        )
      end

      context "when controller is service and view.db is Vm" do
        before(:each) do
          # assigning @view here conflicts with rspec, so we set it inside helper:
          helper.instance_variable_set(:@view, FactoryGirl.create(:miq_report))
          helper.request.parameters[:controller] = "service"
        end

        it "renders a link sans href for ServiceResources" do
          expect( helper.render_quadicon_text(serv_res, row) ).to include("Service Res")
        end

        it "renders a sparkle link for Vms, role permitting" do
          allow(helper).to receive(:role_allows) { true }

          expect( helper.render_quadicon_text(vm, row) ).to include("Fred")
          expect( helper.render_quadicon_text(vm, row) ).to have_selector("[data-miq_sparkle_on]")
        end

        it "renders a link sans href for Vms, with insufficent permissions" do
          expect( helper.render_quadicon_text(vm, row) ).to include("Fred")
          expect( helper.render_quadicon_text(vm, row) ).not_to have_selector("[data-miq_sparkle_on]")
        end

      end
    end

    context "default case" do

    end

  end

  describe "truncate text for quad icons" do
    ["front", "middle", "back"].each do |trunc|
      context "remove #{trunc} of text" do
        before(:each) do
          @settings = {:display => {:quad_truncate => trunc[0]}}
        end

        it "when value is nil" do
          text = helper.send(:truncate_for_quad, nil)
          expect(text).to be_empty
        end

        it "when value is < 13 long" do
          text = helper.send(:truncate_for_quad, "Test")
          expect(text).to eq("Test")
        end

        it "when value is 12 long" do
          text = helper.send(:truncate_for_quad, "ABCDEFGHIJKL")
          expect(text).to eq("ABCDEFGHIJKL")
        end

        it "when value is 13 long" do
          text = helper.send(:truncate_for_quad, "ABCDEooo12345")
          expect(text).to eq(case trunc[0]
                             when "f" then "...DEooo12345"
                             when "m" then "ABCDE...12345"
                             when "b" then "ABCDEooo12..."
                             end)
        end

        it "when value is 25 long" do
          text = helper.send(:truncate_for_quad, "ABCDEooooooooooooooo12345")
          expect(text).to eq(case trunc[0]
                             when "f" then "...ooooo12345"
                             when "m" then "ABCDE...12345"
                             when "b" then "ABCDEooooo..."
                             end)
        end
      end
    end
  end

  describe "render_ext_management_system_quadicon" do
    before(:each) do
      @settings = {:quadicons => {:ems => true}}
      @item = FactoryGirl.build(:ems_infra)
      allow(@item).to receive(:hosts).and_return(%w(foo bar))
      allow(@item).to receive(:image_name).and_return("foo")
      @layout = "ems_infra"
    end

    let(:options) { {:size => 72, :typ => 'grid'} }

    it "doesn't display IP Address in the tooltip" do
      rendered = helper.send(:render_ext_management_system_quadicon, @item, options)
      expect(rendered).not_to match(/IP Address/)
    end

    it "displays Host Name in the tooltip" do
      rendered = helper.send(:render_ext_management_system_quadicon, @item, options)
      expect(rendered).to match(/Hostname/)
    end
  end

  describe "render_service_quadicon" do
    let(:options) { {:size => 72, :typ => 'grid'} }

    context "for service w/o custom picture" do
      let(:service) { FactoryGirl.build(:service, :id => 100) }
      it "renders quadicon" do
        allow(helper).to receive(:url_for).and_return("/path")

        rendered = helper.send(:render_service_quadicon, service, options)
        expect(rendered).to have_selector('div.flobj', :count => 2)
        expect(rendered).to match(/service-[\w]*.png/)
      end
    end

    context "for service w/ custom picture" do
      let(:service) do
        service = FactoryGirl.build(:service, :id => 100)
        allow(service).to receive(:picture).and_return(Pathname.new('/boo/foobar.png'))
        service
      end

      it "renders quadicon" do
        allow(helper).to receive(:url_for).and_return("/path")

        rendered = helper.send(:render_service_quadicon, service, options)
        expect(rendered).to have_selector('div.flobj', :count => 2)
        expect(rendered).to match(/foobar.png/)
      end
    end

    context "for Orchestration Template Catalog Item w/o custom picture" do
      let(:item) { FactoryGirl.build(:service_template_orchestration) }

      it "renders" do
        allow(helper).to receive(:url_for).and_return("/path")
        rendered = helper.send(:render_service_quadicon, item, options)
        expect(rendered).to have_selector('div.flobj', :count => 2)
        expect(rendered).to match(/service_template-[\w]*.png/)
      end
    end
  end
end
