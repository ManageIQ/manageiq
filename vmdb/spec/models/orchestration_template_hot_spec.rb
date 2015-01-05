require "spec_helper"

describe OrchestrationTemplate do
  let(:sample) do
    'spec/fixtures/orchestration_templates/hot_parameters.yml'
  end

  it "parses parameters from a template" do
    template = OrchestrationTemplateHot.new(:content => IO.read(sample))

    groups = template.parameter_groups
    groups.size.should == 2

    assert_general_group(groups[0])
    assert_db_group(groups[1])
  end

  def assert_general_group(group)
    group.label.should == "General parameters"
    group.description.should == "General parameters"

    assert_custom_constraint(group.parameters[0])
    assert_allowed_values(group.parameters[1])
    assert_list_string_type(group.parameters[2])
  end

  def assert_db_group(group)
    group.label.should == "DB parameters"
    group.description.should == "Database related parameters"

    assert_hidden_length_patterns(group.parameters[0])
    assert_min_max_value(group.parameters[1])
    assert_json_type(group.parameters[2])
  end

  def assert_custom_constraint(parameter)
    parameter.should have_attributes(
      :name          => "flavor",
      :label         => "Flavor",
      :description   => "Flavor for the instances to be created",
      :data_type     => "string",
      :default_value => "m1.small",
      :hidden        => false,
    )
    constraints = parameter.constraints
    constraints.size.should == 1
    constraints[0].should be_a OrchestrationTemplate::OrchestrationParameterCustom
    constraints[0].should be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    constraints[0].should have_attributes(
      :description       => "Must be a flavor known to Nova",
      :custom_constraint => "nova.flavor"
    )
  end

  def assert_list_string_type(parameter)
    parameter.should have_attributes(
      :name          => "cartridges",
      :label         => "Cartridges",
      :description   => "Cartridges to install. \"all\" for all cartridges; \"standard\" for all cartridges except for JBossEWS or JBossEAP\n",
      :data_type     => "string",  # HOT has type comma_delimited_list, but all examples use type string. Why?
      :default_value => "cron,diy,haproxy,mysql,nodejs,perl,php,postgresql,python,ruby",
      :hidden        => false,
      :constraints   => [],
    )
  end

  def assert_allowed_values(parameter)
    parameter.should have_attributes(
      :name          => "image_id",
      :label         => "Image", # String#titleize removes trailing id
      :description   => "ID of the image to use for the instance to be created.",
      :data_type     => "string",
      :default_value => "F18-x86_64-cfntools",
      :hidden        => false,
    )
    constraints = parameter.constraints
    constraints.size.should == 1
    constraints[0].should be_a OrchestrationTemplate::OrchestrationParameterAllowed
    constraints[0].should be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    constraints[0].should have_attributes(
      :description    => "Image ID must be either F18-i386-cfntools or F18-x86_64-cfntools.",
      :allowed_values => ["F18-i386-cfntools", "F18-x86_64-cfntools"]
    )
  end

  def assert_min_max_value(parameter)
    parameter.should have_attributes(
      :name          => "db_port",
      :label         => "Port Number",  # provided by template
      :description   => "Database port number",
      :data_type     => "number",
      :default_value => 50_000,
      :hidden        => false,
    )
    constraints = parameter.constraints
    constraints.size.should == 1
    constraints[0].should be_a OrchestrationTemplate::OrchestrationParameterRange
    constraints[0].should be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    constraints[0].should have_attributes(
      :description => "Port number must be between 40000 and 60000",
      :min_value   => 40_000,
      :max_value   => 60_000
    )
  end

  def assert_hidden_length_patterns(parameter)
    parameter.should have_attributes(
      :name          => "admin_pass",
      :label         => "Admin Pass",
      :description   => "Admin password",
      :data_type     => "string",
      :default_value => nil,
      :hidden        => true
    )
    constraints = parameter.constraints
    constraints.size.should == 3

    constraints[0].should be_a OrchestrationTemplate::OrchestrationParameterLength
    constraints[0].should be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    constraints[0].should have_attributes(
      :description => "Admin password must be between 6 and 8 characters long.\n",
      :min_length  => 6,
      :max_length  => 8
    )

    constraints[1].should be_a OrchestrationTemplate::OrchestrationParameterPattern
    constraints[1].should be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    constraints[1].should have_attributes(
      :description => "Password must consist of characters and numbers only",
      :pattern     => "[a-zA-Z0-9]+"
    )

    constraints[2].should be_a OrchestrationTemplate::OrchestrationParameterPattern
    constraints[2].should have_attributes(
      :description => "Password must start with an uppercase character",
      :pattern     => "[A-Z]+[a-zA-Z0-9]*"
    )
  end

  def assert_json_type(parameter)
    parameter.should have_attributes(
      :name          => "metadata",
      :label         => "Metadata",
      :description   => nil,
      :data_type     => "json",
      :default_value => nil,
      :hidden        => false,
      :constraints   => [],
    )
  end
end
