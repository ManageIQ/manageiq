require 'spec_helper'

describe "VmVmware" do
  context "vim" do
    let(:ems) { FactoryGirl.create(:ems_vmware) }
    let(:provider_object) do
      double("vm_vmware_provider_object", :destroy => nil).as_null_object
    end
    let(:vm)  { FactoryGirl.create(:vm_vmware, :ext_management_system => ems) }

    it "#invoke_vim_ws" do
      expect(vm).to receive(:with_provider_object).and_yield(provider_object)
      expect(provider_object).to receive(:send).and_return("nada")

      ems.invoke_vim_ws(:do_nothing, vm).should eq("nada")
    end
  end
end
