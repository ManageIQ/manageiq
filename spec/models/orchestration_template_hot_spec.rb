describe OrchestrationTemplateHot do
  describe ".eligible_manager_types" do
    it "lists the classes of eligible managers" do
      OrchestrationTemplateHot.eligible_manager_types.each do |klass|
        expect(klass <= ManageIQ::Providers::Openstack::CloudManager).to be_truthy
      end
    end
  end

  let(:valid_template) { FactoryGirl.create(:orchestration_template_hot_with_content) }

  context "when a raw template in YAML format is given" do
    it "parses parameters from a template" do
      groups = valid_template.parameter_groups
      expect(groups.size).to eq(2)

      assert_general_group(groups[0])
      assert_db_group(groups[1])
    end
  end

  def assert_general_group(group)
    expect(group.label).to eq("General parameters")
    expect(group.description).to eq("General parameters")

    assert_custom_constraint(group.parameters[0])
    assert_allowed_values(group.parameters[1])
    assert_list_string_type(group.parameters[2])
  end

  def assert_db_group(group)
    expect(group.label).to be_nil
    expect(group.description).to be_nil

    assert_hidden_length_patterns(group.parameters[0])
    assert_min_max_value(group.parameters[1])
    assert_json_type(group.parameters[2])
  end

  def assert_custom_constraint(parameter)
    expect(parameter).to have_attributes(
      :name          => "flavor",
      :label         => "Flavor",
      :description   => "Flavor for the instances to be created",
      :data_type     => "string",
      :default_value => "m1.small",
      :hidden        => false,
      :required      => true
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a OrchestrationTemplate::OrchestrationParameterCustom
    expect(constraints[0]).to be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[0]).to have_attributes(
      :description       => "Must be a flavor known to Nova",
      :custom_constraint => "nova.flavor"
    )
  end

  def assert_list_string_type(parameter)
    expect(parameter).to have_attributes(
      :name          => "cartridges",
      :label         => "Cartridges",
      :description   => "Cartridges to install. \"all\" for all cartridges; \"standard\" for all cartridges except for JBossEWS or JBossEAP\n",
      :data_type     => "string",  # HOT has type comma_delimited_list, but all examples use type string. Why?
      :default_value => "cron,diy,haproxy,mysql,nodejs,perl,php,postgresql,python,ruby",
      :hidden        => false,
      :required      => true,
      :constraints   => [],
    )
  end

  def assert_allowed_values(parameter)
    expect(parameter).to have_attributes(
      :name          => "image_id",
      :label         => "Image", # String#titleize removes trailing id
      :description   => "ID of the image to use for the instance to be created.",
      :data_type     => "string",
      :default_value => "F18-x86_64-cfntools",
      :hidden        => false,
      :required      => true
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a OrchestrationTemplate::OrchestrationParameterAllowed
    expect(constraints[0]).to be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[0]).to have_attributes(
      :description    => "Image ID must be either F18-i386-cfntools or F18-x86_64-cfntools.",
      :allowed_values => ["F18-i386-cfntools", "F18-x86_64-cfntools"]
    )
  end

  def assert_min_max_value(parameter)
    expect(parameter).to have_attributes(
      :name          => "db_port",
      :label         => "Port Number",  # provided by template
      :description   => "Database port number",
      :data_type     => "number",
      :default_value => 50_000,
      :hidden        => false,
      :required      => true
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a OrchestrationTemplate::OrchestrationParameterRange
    expect(constraints[0]).to be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[0]).to have_attributes(
      :description => "Port number must be between 40000 and 60000",
      :min_value   => 40_000,
      :max_value   => 60_000
    )
  end

  def assert_hidden_length_patterns(parameter)
    expect(parameter).to have_attributes(
      :name          => "admin_pass",
      :label         => "Admin Pass",
      :description   => "Admin password",
      :data_type     => "string",
      :default_value => nil,
      :hidden        => true,
      :required      => true
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(3)

    expect(constraints[0]).to be_a OrchestrationTemplate::OrchestrationParameterLength
    expect(constraints[0]).to be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[0]).to have_attributes(
      :description => "Admin password must be between 6 and 8 characters long.\n",
      :min_length  => 6,
      :max_length  => 8
    )

    expect(constraints[1]).to be_a OrchestrationTemplate::OrchestrationParameterPattern
    expect(constraints[1]).to be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[1]).to have_attributes(
      :description => "Password must consist of characters and numbers only",
      :pattern     => "[a-zA-Z0-9]+"
    )

    expect(constraints[2]).to be_a OrchestrationTemplate::OrchestrationParameterPattern
    expect(constraints[2]).to have_attributes(
      :description => "Password must start with an uppercase character",
      :pattern     => "[A-Z]+[a-zA-Z0-9]*"
    )
  end

  def assert_json_type(parameter)
    expect(parameter).to have_attributes(
      :name          => "metadata",
      :label         => "Metadata",
      :description   => nil,
      :data_type     => "json",
      :default_value => nil,
      :hidden        => false,
      :required      => true,
      :constraints   => [],
    )
  end

  describe '#validate_format' do
    it 'passes validation if no content' do
      template = OrchestrationTemplateHot.new
      expect(template.validate_format).to be_nil
    end

    it 'passes validation with correct YAML content' do
      expect(valid_template.validate_format).to be_nil
    end

    it 'fails validations with incorrect YAML content' do
      template = OrchestrationTemplateHot.new(:content => ":-Invalid:\n-String")
      expect(template.validate_format).not_to be_nil
    end
  end

  describe '#deployment_options' do
    it do
      options = subject.deployment_options
      assert_deployment_option(options[0], "tenant_name", :OrchestrationParameterAllowedDynamic, true)
      assert_deployment_option(options[1], "stack_name", :OrchestrationParameterPattern, true)
      assert_deployment_option(options[2], "stack_onfailure", :OrchestrationParameterAllowed, false)
      assert_deployment_option(options[3], "stack_timeout", nil, false, 'integer')
    end
  end

  def assert_deployment_option(option, name, constraint_type, required, data_type = 'string')
    expect(option.name).to eq(name)
    expect(option.data_type).to eq(data_type)
    expect(option.required?).to eq(required)
    expect(option.constraints[0]).to be_kind_of("OrchestrationTemplate::#{constraint_type}".constantize) if constraint_type
  end
end
