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

      it "Vm" do
        result = described_class.model_details("Vm", :typ=>"tag", :include_model=>true, :include_my_tags=>true, :userid=>"admin")
        result.select { |r| r.first == "VM and Instance.My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
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
      it "Vm" do
        result = described_class.model_details("Vm", :typ => "all", :include_model => false, :include_tags => true)
        result.select { |r| r.first == "My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end

      it "Service" do
        result = described_class.model_details("Service", :typ => "all", :include_model => false, :include_tags => true)
        result.select { |r| r.first == "My Company Tags : Auto Approve - Max CPU" }.should_not be_empty
      end
    end
  end
end
