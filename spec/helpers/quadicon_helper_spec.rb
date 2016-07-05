require 'spec_helper'

describe QuadiconHelper do
  describe "#render_quadicon" do
    subject { helper.render_quadicon(item, {}) }

    let(:item) do
      FactoryGirl.create(:vm_vmware)
    end

    it "renders quadicon for a vmware vm" do
      expect(subject).to have_selector('div#quadicon')
      expect(subject).to have_selector('div#quadicon div.flobj')
    end
  end

  describe "#render_quadicon_text" do
    before(:each) do
      @settings = {:display => {:quad_truncate => "m"}}
    end

    subject { helper.render_quadicon_text(item, row) }

    let(:row) do
      Ruport::Data::Record.new(:id => 10000000000534, "name" => name)
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
end
