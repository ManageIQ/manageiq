require "spec_helper"

describe Hardware do
  context "integration" do
    before(:each) do
      @vm_hw = FactoryGirl.create(:hardware)
      @vm    = FactoryGirl.create(:vm_vmware, :hardware => @vm_hw)

      @template_hw = FactoryGirl.create(:hardware)
      @template    = FactoryGirl.create(:template_vmware, :hardware => @template_hw)

      @host_hw = FactoryGirl.create(:hardware)
      @host    = FactoryGirl.create(:host, :hardware => @host_hw)
    end

    it "#vm_or_template" do
      @vm_hw.vm_or_template.should == @vm
      @template_hw.vm_or_template.should == @template
      @host_hw.vm_or_template.should     be_nil
    end

    it "#vm" do
      @vm_hw.vm.should == @vm
      @template_hw.vm.should be_nil
      @host_hw.vm.should     be_nil
    end

    it "#miq_template" do
      @vm_hw.miq_template.should       be_nil
      @template_hw.miq_template.should == @template
      @host_hw.miq_template.should     be_nil
    end

    it "#host" do
      @vm_hw.host.should       be_nil
      @template_hw.host.should be_nil
      @host_hw.host.should == @host
    end
  end

  describe "#sockets" do
    it "returns 0 when logical cpus is nil" do
      hardware = FactoryGirl.build(:hardware, :logical_cpus => nil, :cores_per_socket => 1)
      expect(hardware.sockets).to eq(0)
    end

    it "returns 0 when cores_per_socket is nil" do
      hardware = FactoryGirl.build(:hardware, :logical_cpus => 1, :cores_per_socket => nil)
      expect(hardware.sockets).to eq(0)
    end

    it "returns 0 when cores_per_socket is 0" do
      hardware = FactoryGirl.build(:hardware, :logical_cpus => 0, :cores_per_socket => 0)
      expect(hardware.sockets).to eq(0)
    end

    it "returns logical_cpus / cores_per_socket" do
      hardware = FactoryGirl.build(:hardware, :logical_cpus => 8, :cores_per_socket => 4)
      expect(hardware.sockets).to eq(2)
    end
  end
end
