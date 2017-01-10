RSpec.describe Api::ServiceTemplateWorkflow do
  describe ".create" do
    it "creates a workflow" do
      provision_action = instance_double("Provision Action")
      service_template = instance_double("ServiceTemplate", :provision_action => provision_action)
      workflow = instance_double(ResourceActionWorkflow)
      user = instance_double(User)
      allow(User).to receive(:current_user).and_return(user)
      allow(ResourceActionWorkflow).to(receive(:new)
                                        .with(anything, user, provision_action, :target => service_template)
                                        .and_return(workflow))

      expect(described_class.create(service_template, {})).to be(workflow)
    end

    it "creates a workflow and sets service request values if passed" do
      provision_action = instance_double("Provision Action")
      service_template = instance_double("ServiceTemplate", :provision_action => provision_action)
      workflow = instance_double(ResourceActionWorkflow)
      user = instance_double(User)
      allow(User).to receive(:current_user).and_return(user)
      allow(ResourceActionWorkflow).to(receive(:new)
                                        .with(anything, user, provision_action, :target => service_template)
                                        .and_return(workflow))

      expect(workflow).to receive(:set_value).with("text", "foo")

      expect(described_class.create(service_template, "text" => "foo")).to be(workflow)
    end
  end
end
