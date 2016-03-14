require 'spec_helper'
include ApplicationHelper
include ERB::Util

describe QuadiconHelper do
  describe "#render_quadicon" do
    subject { render_quadicon(item, {}) }

    let(:item) do
      FactoryGirl.create(:vm_vmware)#, :type => ManageIQ::Providers::Vmware::InfraManager::Vm.name)
    end

    it "renders quadicon for a vmware vm" do
      expect(subject).to have_selector('div#quadicon')
      expect(subject).to have_selector('div#quadicon div.flobj')
    end
  end

  describe "#render_quadicon_text" do
    subject { render_quadicon_text(item, row) }

    let(:item) do
      FactoryGirl.create(:vm_vmware)
    end

    let(:row) do
      Ruport::Data::Record.new(:id => 10000000000534)
    end

    it "render text for a vmware vm" do
      expect(subject).to have_selector('a')
    end
  end
end
