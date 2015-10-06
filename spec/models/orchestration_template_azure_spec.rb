require "spec_helper"

describe OrchestrationTemplateAzure do
  describe ".eligible_manager_types" do
    it "lists the classes of eligible managers" do
      OrchestrationTemplateAzure.eligible_manager_types.each do |klass|
        (klass <= ManageIQ::Providers::Azure::CloudManager).should be_true
      end
    end
  end

  let(:valid_template) { FactoryGirl.create(:orchestration_template_azure_with_content) }

  context "when a raw template in JSON format is given" do
    it "parses parameters from a template" do
      groups = valid_template.parameter_groups
      groups.size.should == 1
      groups[0].label.should == "Parameters"

      param_hash = groups[0].parameters.index_by(&:name)
      param_hash.size.should == 3
      assert_string_type(param_hash["adminUsername"])
      assert_secret_type(param_hash["adminPassword"])
      assert_allowed_values(param_hash["hostingPlanSku"])
    end
  end

  def assert_secret_type(parameter)
    parameter.should have_attributes(
      :name          => "adminPassword",
      :label         => "Admin Password",
      :description   => "Admin password",
      :data_type     => "securestring",
      :default_value => nil,
      :hidden        => true,
      :constraints   => [],
    )
  end

  def assert_string_type(parameter)
    parameter.should have_attributes(
      :name          => "adminUsername",
      :label         => "Admin Username",
      :description   => "Administrator username",
      :data_type     => "string",
      :default_value => nil,
      :hidden        => false,
      :constraints   => [],
    )
  end

  def assert_allowed_values(parameter)
    parameter.should have_attributes(
      :name          => "hostingPlanSku",
      :label         => "Hosting Plan Sku",
      :description   => nil,
      :data_type     => "string",
      :default_value => "Free",
      :hidden        => false,
    )
    constraints = parameter.constraints
    constraints.size.should == 1
    constraints[0].should be_a OrchestrationTemplate::OrchestrationParameterAllowed
    constraints[0].should be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    constraints[0].should have_attributes(
      :description    => nil,
      :allowed_values => ["Free", "Shared", "Basic", "Standard", "Premium"]
    )
  end

  describe '#validate_format' do
    it 'passes validation if no content' do
      template = OrchestrationTemplateAzure.new
      template.validate_format.should be_nil
    end

    it 'passes validation with correct JSON content' do
      valid_template.validate_format.should be_nil
    end

    it 'fails validations with incorrect JSON content' do
      template = OrchestrationTemplateAzure.new(:content => "invalid string")
      template.validate_format.should_not be_nil
    end
  end
end
