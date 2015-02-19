require "spec_helper"

describe MiqExpression do
  describe ".model_details" do
    before do
      cat = FactoryGirl.create(:classification,
                               :description  => "Auto Approve - Max CPU",
                               :name         => "prov_max_cpu",
                               :single_value => true,
                               :show         => true,
                               :parent_id    => 0
                              )
      cat.add_entry(:description  => "1",
                    :read_only    => "0",
                    :syntax       => "string",
                    :name         => "1",
                    :example_text => nil,
                    :default      => true,
                    :single_value => "1"
                   )
    end

    context "with :typ=>tag" do
      it "VmInfra" do
        result = described_class.model_details("VmInfra", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.map(&:first).should include("Virtual Machine.My Company Tags : Auto Approve - Max CPU")
      end

      it "VmCloud" do
        result = described_class.model_details("VmCloud", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.map(&:first).should include("Instance.My Company Tags : Auto Approve - Max CPU")
        result.map(&:first).should_not include("Instance.VM and Instance.My Company Tags : Auto Approve - Max CPU")
      end

      it "VmOrTemplate" do
        result = described_class.model_details("VmOrTemplate",
                                               :typ             => "tag",
                                               :include_model   => true,
                                               :include_my_tags => true,
                                               :userid          => "admin"
        )
        result.map(&:first).should include("VM or Template.My Company Tags : Auto Approve - Max CPU")
      end

      it "TemplateInfra" do
        result = described_class.model_details("TemplateInfra", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.map(&:first).should include("Template.My Company Tags : Auto Approve - Max CPU")
      end

      it "TemplateCloud" do
        result = described_class.model_details("TemplateCloud", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.map(&:first).should include("Image.My Company Tags : Auto Approve - Max CPU")
      end

      it "MiqTemplate" do
        result = described_class.model_details("MiqTemplate", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.map(&:first).should include("VM Template and Image.My Company Tags : Auto Approve - Max CPU")
      end

      it "EmsInfra" do
        result = described_class.model_details("EmsInfra", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.map(&:first).should include("Infrastructure Provider.My Company Tags : Auto Approve - Max CPU")
      end

      it "EmsCloud" do
        result = described_class.model_details("EmsCloud", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.map(&:first).should include("Cloud Provider.My Company Tags : Auto Approve - Max CPU")
      end
    end

    context "with :typ=>all" do
      it "VmOrTemplate" do
        result = described_class.model_details("VmOrTemplate",
                                               :typ           => "all",
                                               :include_model => false,
                                               :include_tags  => true)
        result.map(&:first).should include("My Company Tags : Auto Approve - Max CPU")
      end

      it "Service" do
        result = described_class.model_details("Service", :typ => "all", :include_model => false, :include_tags => true)
        result.map(&:first).should include("My Company Tags : Auto Approve - Max CPU")
      end
    end
  end

  context ".build_relats" do
    it "AvailabilityZone" do
      result = described_class.build_relats("AvailabilityZone")
      expect(result.fetch_path(:reflections, :ext_management_system, :parent, :class_path).split(".").last).to eq("ems_cloud")
      expect(result.fetch_path(:reflections, :ext_management_system, :parent, :assoc_path).split(".").last).to eq("ext_management_system")
    end

    it "VmInfra" do
      result = described_class.build_relats("VmInfra")
      expect(result.fetch_path(:reflections, :evm_owner, :parent, :class_path).split(".").last).to eq("evm_owner")
      expect(result.fetch_path(:reflections, :evm_owner, :parent, :assoc_path).split(".").last).to eq("evm_owner")
      expect(result.fetch_path(:reflections, :linux_initprocesses, :parent, :class_path).split(".").last).to eq("linux_initprocesses")
      expect(result.fetch_path(:reflections, :linux_initprocesses, :parent, :assoc_path).split(".").last).to eq("linux_initprocesses")
    end

    it "Vm" do
      result = described_class.build_relats("Vm")
      expect(result.fetch_path(:reflections, :users, :parent, :class_path).split(".").last).to eq("users")
      expect(result.fetch_path(:reflections, :users, :parent, :assoc_path).split(".").last).to eq("users")
    end

    it "OrchestrationStack" do
      result = described_class.build_relats("OrchestrationStack")
      expect(result.fetch_path(:reflections, :vms, :parent, :class_path).split(".").last).to eq("vm_clouds")
      expect(result.fetch_path(:reflections, :vms, :parent, :assoc_path).split(".").last).to eq("vms")
    end
  end

  context ".determine_relat_path" do
    subject { described_class.determine_relat_path(@ref) }

    it "when association name is same as class name" do
      @ref = Vm.reflect_on_association(:miq_group)
      expect(subject).to eq(@ref.name.to_s)
    end

    it "when association name is different from class name" do
      @ref = Vm.reflect_on_association(:evm_owner)
      expect(subject).to eq(@ref.name.to_s)
    end

    context "when class name is a subclass of association name" do
      it "one_to_one relation" do
        @ref = AvailabilityZone.reflect_on_association(:ext_management_system)
        expect(subject).to eq(@ref.klass.model_name.singular)
      end

      it "one_to_many relation" do
        @ref = OrchestrationStack.reflect_on_association(:vms)
        expect(subject).to eq(@ref.klass.model_name.plural)
      end
    end
  end
end
