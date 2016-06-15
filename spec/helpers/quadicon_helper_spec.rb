require 'spec_helper'

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

  describe "#render_quadicon_text" do
    before(:each) do
      @settings = {:display => {:quad_truncate => "front"}}
    end

    subject { helper.render_quadicon_text(item, row) }

    let(:row) do
      Ruport::Data::Record.new(:id => 10_000_000_000_534, "name" => name)
    end

    context "text for a VM" do
      let(:item) do
        FactoryGirl.create(:vm_vmware, :name => "vm_0000000000001")
      end

      let(:name) { item.name }

      it "renders text for a vmware vm" do
        expect(subject).to have_link("vm_00...00001")
      end
    end

    context "text for Floating IP" do
      let(:item) do
        FactoryGirl.create(:floating_ip_openstack)
      end

      let(:name) { nil }

      it "renders a label for Floating IPs" do
        expect(subject).to have_link(item.address)
      end
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
