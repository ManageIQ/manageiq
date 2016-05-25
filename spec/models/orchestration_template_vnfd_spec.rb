describe OrchestrationTemplateVnfd do
  describe ".eligible_manager_types" do
    it "lists the classes of eligible managers" do
      OrchestrationTemplateVnfd.eligible_manager_types.each do |klass|
        expect(klass <= ManageIQ::Providers::Openstack::CloudManager).to be_truthy
      end
    end
  end

  let(:valid_template) { FactoryGirl.create(:orchestration_template_vnfd_with_content) }


   describe '#validate_format' do
    it 'passes validation if no content' do
      template = OrchestrationTemplateVnfd.new
      expect(template.validate_format).to be_nil
    end

    it 'passes validation with correct YAML content' do
      expect(valid_template.validate_format).to be_nil
    end

    it 'fails validations with incorrect YAML content' do
      template = OrchestrationTemplateVnfd.new(:content => ":-Invalid:\n-String")
      expect(template.validate_format).not_to be_nil
    end
  end
end
