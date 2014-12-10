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
        result.select { |r| r.first == "Virtual Machine.My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end

      it "VmCloud" do
        result = described_class.model_details("VmCloud", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.select { |r| r.first == "Instance.My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
        result.select { |r| r.first == "Instance.VM and Instance.My Company Tags : Auto Approve - Max CPU" }.should be_empty
      end

      it "VmOrTemplate" do
        result = described_class.model_details("VmOrTemplate",
                                               :typ             => "tag",
                                               :include_model   => true,
                                               :include_my_tags => true,
                                               :userid          => "admin"
        )
        result.select { |r| r.first == "VM or Template.My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end

      it "TemplateInfra" do
        result = described_class.model_details("TemplateInfra", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.select { |r| r.first == "Template.My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end

      it "TemplateCloud" do
        result = described_class.model_details("TemplateCloud", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.select { |r| r.first == "Image.My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end

      it "MiqTemplate" do
        result = described_class.model_details("MiqTemplate", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.select { |r| r.first == "VM Template and Image.My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end

      it "EmsInfra" do
        result = described_class.model_details("EmsInfra", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.select { |r| r.first == "Infrastructure Provider.My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end

      it "EmsCloud" do
        result = described_class.model_details("EmsCloud", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.select { |r| r.first == "Cloud Provider.My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end
    end

    context "with :typ=>all" do
      it "VmOrTemplate" do
        result = described_class.model_details("VmOrTemplate",
                                               :typ           => "all",
                                               :include_model => false,
                                               :include_tags  => true)
        result.select { |r| r.first == "My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end

      it "Service" do
        result = described_class.model_details("Service", :typ => "all", :include_model => false, :include_tags => true)
        result.select { |r| r.first == "My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end
    end
  end

  context ".build_relats" do
    it "AvailabilityZone" do
      result = described_class.build_relats("AvailabilityZone")
      expect(result.fetch_path(:reflections, :ext_management_system, :parent, :path).split(".").last).to eq("ems/cloud_provider")
    end

    it "VmInfra" do
      result = described_class.build_relats("VmInfra")
      expect(result.fetch_path(:reflections, :evm_owner, :parent, :path).split(".").last).to eq("evm_owner")
      expect(result.fetch_path(:reflections, :linux_initprocesses, :parent, :path).split(".").last).to eq("linux_initprocesses")
    end

    it "Vm" do
      result = described_class.build_relats("Vm")
      expect(result.fetch_path(:reflections, :users, :parent, :path).split(".").last).to eq("users")
    end
  end

  context ".determine_relat_path" do
    subject { described_class.determine_relat_path(@ref) }

    it "when association name is same as class name" do
      @ref = Vm.reflections[:miq_group]
      expect(subject).to eq(@ref.name.to_s)
    end

    it "when association name is different from class name" do
      @ref = Vm.reflections[:evm_owner]
      expect(subject).to eq(@ref.name.to_s)
    end

    it "when class name is a subclass of association name" do
      @ref = AvailabilityZone.reflections[:ext_management_system]
      expect(subject).to eq(@ref.klass.to_s.underscore)
    end
  end
end
