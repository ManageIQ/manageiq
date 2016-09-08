describe ManageIQ::Providers::Azure::CloudManager::OrchestrationServiceOptionConverter do
  subject { ManageIQ::Providers::Azure::CloudManager::OrchestrationServiceOptionConverter.new(dialog_options) }

  describe "#create_stack_options" do
    context "both resource_group and new_resource_group exist" do
      let(:dialog_options) { {'dialog_resource_group' => 'abc', 'dialog_new_resource_group' => 'xyz'} }

      it "prefers resource_group over new_resource_group" do
        expect(subject.stack_create_options).to have_attributes(:resource_group => 'abc')
      end
    end

    context "resource_group is blank" do
      let(:dialog_options) { {'dialog_resource_group' => '', 'dialog_new_resource_group' => 'xyz'} }

      it "takes new_resource_group" do
        expect(subject.stack_create_options).to have_attributes(:resource_group => 'xyz')
      end
    end
  end
end
