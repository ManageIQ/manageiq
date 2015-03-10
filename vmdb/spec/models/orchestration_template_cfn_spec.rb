require "spec_helper"

describe OrchestrationTemplateCfn do
  describe ".eligible_manager_types" do
    it "lists the classes of eligible managers" do
      OrchestrationTemplateCfn.eligible_manager_types.each do |klass|
        (klass <= EmsAmazon || klass <= EmsOpenstack).should be_true
      end
    end
  end

  let(:sample) do
    'spec/fixtures/orchestration_templates/cfn_parameters.json'
  end

  let(:valid_template) do
    OrchestrationTemplateCfn.new(:content => IO.read(sample))
  end

  context "when a raw template in JSON format is given" do


    it "parses parameters from a template" do
      groups = valid_template.parameter_groups
      groups.size.should == 1
      groups[0].label.should == "Parameters"

      param_hash = groups[0].parameters.index_by(&:name)
      param_hash.size.should == 6
      assert_aws_type(param_hash["KeyName"])
      assert_list_aws_type(param_hash["Subnets"])
      assert_list_string_type(param_hash["AZs"])
      assert_allowed_values(param_hash["WebServerInstanceType"])
      assert_min_max_value(param_hash["SecondaryIPAddressCount"])
      assert_hidden_length_pattern(param_hash["MasterUserPassword"])
    end
  end

  def assert_aws_type(parameter)
    parameter.should have_attributes(
      :name          => "KeyName",
      :label         => "Key Name",
      :description   => "Name of an existing EC2 KeyPair to enable SSH access to the instances",
      :data_type     => "AWS::EC2::KeyPair::KeyName",
      :default_value => nil,
      :hidden        => false,
      :constraints   => [],
    )
  end

  def assert_list_aws_type(parameter)
    parameter.should have_attributes(
      :name          => "Subnets",
      :label         => "Subnets",
      :description   => "The list of SubnetIds in your Virtual Private Cloud (VPC)",
      :data_type     => "List<AWS::EC2::Subnet::Id>",
      :default_value => nil,
      :hidden        => false,
      :constraints   => [],
    )
  end

  def assert_list_string_type(parameter)
    parameter.should have_attributes(
      :name          => "AZs",
      :label         => "A Zs",
      :description   => "The list of AvailabilityZones for your Virtual Private Cloud (VPC)",
      :data_type     => "List<String>",
      :default_value => nil,
      :hidden        => false,
      :constraints   => [],
    )
  end

  def assert_allowed_values(parameter)
    parameter.should have_attributes(
      :name          => "WebServerInstanceType",
      :label         => "Web Server Instance Type",
      :description   => "WebServer Server EC2 instance type",
      :data_type     => "String",
      :default_value => "m1.small",
      :hidden        => false,
    )
    constraints = parameter.constraints
    constraints.size.should == 1
    constraints[0].should be_a OrchestrationTemplate::OrchestrationParameterAllowed
    constraints[0].should be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    constraints[0].should have_attributes(
      :description    => "must be a valid EC2 instance type.",
      :allowed_values => ["t2.small", "t2.medium", "m1.small"]
    )
  end

  def assert_min_max_value(parameter)
    parameter.should have_attributes(
      :name          => "SecondaryIPAddressCount",
      :label         => "Secondary Ip Address Count",
      :description   => "Number of secondary IP addresses to assign to the network interface (1-5)",
      :data_type     => "Number",
      :default_value => "1",
      :hidden        => false,
    )
    constraints = parameter.constraints
    constraints.size.should == 1
    constraints[0].should be_a OrchestrationTemplate::OrchestrationParameterRange
    constraints[0].should be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    constraints[0].should have_attributes(
      :description => "must be a number from 1 to 5.",
      :min_value   => 1,
      :max_value   => 5
    )
  end

  def assert_hidden_length_pattern(parameter)
    parameter.should have_attributes(
      :name          => "MasterUserPassword",
      :label         => "Master User Password",
      :description   => "The password associated with the aster user account for the redshift cluster that is being created. ",
      :data_type     => "String",
      :default_value => nil,
      :hidden        => true,
    )
    constraints = parameter.constraints
    constraints.size.should == 2

    constraint_hash = constraints.index_by(&:class)
    constraint_hash[OrchestrationTemplate::OrchestrationParameterPattern].should have_attributes(
      :description => "must contain only alphanumeric characters.",
      :pattern     => "[a-zA-Z0-9]*",
    )

    constraint_hash[OrchestrationTemplate::OrchestrationParameterLength].should have_attributes(
      :description => "must contain only alphanumeric characters.",
      :min_length  => 1,
      :max_length  => 41
    )
  end

  describe '#validate_format' do
    it 'passes validation if no content' do
      template = OrchestrationTemplateCfn.new
      template.validate_format.should be_nil
    end

    it 'passes validation with correct JSON content' do
      valid_template.validate_format.should be_nil
    end

    it 'fails validations with incorrect JSON content' do
      template = OrchestrationTemplateCfn.new(:content => "invalid string")
      template.validate_format.should_not be_nil
    end
  end
end
