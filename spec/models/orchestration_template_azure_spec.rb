describe OrchestrationTemplateAzure do
  describe ".eligible_manager_types" do
    it "lists the classes of eligible managers" do
      OrchestrationTemplateAzure.eligible_manager_types.each do |klass|
        expect(klass <= ManageIQ::Providers::Azure::CloudManager).to be_truthy
      end
    end
  end

  let(:valid_template) { FactoryGirl.create(:orchestration_template_azure_with_content) }

  context "when a raw template in JSON format is given" do
    it "parses parameters from a template" do
      groups = valid_template.parameter_groups
      expect(groups.size).to eq(1)
      expect(groups[0].label).to eq("Parameters")

      param_hash = groups[0].parameters.index_by(&:name)
      expect(param_hash.size).to eq(3)
      assert_string_type(param_hash["adminUsername"])
      assert_secret_type(param_hash["adminPassword"])
      assert_allowed_values(param_hash["hostingPlanSku"])
    end
  end

  def assert_secret_type(parameter)
    expect(parameter).to have_attributes(
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
    expect(parameter).to have_attributes(
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
    expect(parameter).to have_attributes(
      :name          => "hostingPlanSku",
      :label         => "Hosting Plan Sku",
      :description   => nil,
      :data_type     => "string",
      :default_value => "Free",
      :hidden        => false,
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a OrchestrationTemplate::OrchestrationParameterAllowed
    expect(constraints[0]).to be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[0]).to have_attributes(
      :description    => nil,
      :allowed_values => ["Free", "Shared", "Basic", "Standard", "Premium"]
    )
  end

  describe '#validate_format' do
    it 'passes validation if no content' do
      template = OrchestrationTemplateAzure.new
      expect(template.validate_format).to be_nil
    end

    it 'passes validation with correct JSON content' do
      expect(valid_template.validate_format).to be_nil
    end

    it 'fails validations with incorrect JSON content' do
      template = OrchestrationTemplateAzure.new(:content => "invalid string")
      expect(template.validate_format).not_to be_nil
    end
  end
end
