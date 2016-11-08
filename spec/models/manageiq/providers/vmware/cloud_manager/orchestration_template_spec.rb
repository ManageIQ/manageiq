describe ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate do
  describe ".eligible_manager_types" do
    it "lists the classes of eligible managers" do
      ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate.eligible_manager_types.each do |klass|
        expect(klass <= ManageIQ::Providers::Vmware::CloudManager).to be_truthy
      end
    end
  end

  let(:valid_template) { FactoryGirl.create(:orchestration_template_vmware_cloud_with_content) }

  describe '#validate_format' do
    it 'passes validation if no content' do
      template = ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate.new
      expect(template.validate_format).to be_nil
    end

    it 'passes validation with correct OVF content' do
      expect(valid_template.validate_format).to be_nil
    end

    it 'fails validations with incorrect OVF content' do
      template = ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate.new(:content => "Invalid String")
      expect(template.validate_format).not_to be_nil
    end
  end
end
