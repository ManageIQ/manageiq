RSpec.describe ContainerNode do
  subject { FactoryBot.create(:container_node) }

  include_examples "MiqPolicyMixin"

  describe "#operating_system" do
    it "handles null computer system" do
      expect(subject.operating_system).to be_nil
    end

    it "handles null operating system" do
      FactoryBot.create(:computer_system, :managed_entity => subject)
      expect(subject.operating_system).to be_nil
    end

    it "delegates value" do
      os = FactoryBot.create(:operating_system, :distribution => "coreos")
      FactoryBot.create(:computer_system, :managed_entity => subject, :operating_system => os)
      expect(subject.operating_system).to eq(os)
    end
  end

  describe "#ready_condition" do
    it "handles no container_conditions" do
      expect(subject.ready_condition).to be_nil
    end

    it "handles other container conditions" do
      FactoryBot.create(:container_conditions, :name => "Other", :container_entity => subject)
      expect(subject.ready_condition).to be_nil
    end

    it "finds container conditions" do
      ready = FactoryBot.create(:container_conditions, :name => "Ready", :container_entity => subject, :status => "Great")
      FactoryBot.create(:container_conditions, :name => "Other", :container_entity => subject)
      expect(subject.ready_condition).to eq(ready)
    end
  end

  describe "#ready_condition_status" do
    it "handles no container_conditions" do
      expect(subject.ready_condition_status).to eq("None")
    end

    it "handles other container conditions" do
      FactoryBot.create(:container_conditions, :name => "Other", :container_entity => subject)
      expect(subject.ready_condition_status).to eq("None")
    end

    it "finds container conditions" do
      FactoryBot.create(:container_conditions, :name => "Ready", :container_entity => subject, :status => "Great")
      FactoryBot.create(:container_conditions, :name => "Other", :container_entity => subject, :status => "Not Good")
      expect(subject.ready_condition_status).to eq("Great")
    end
  end

  describe "#system_distribution" do # on os
    it "handles null computer system" do
      expect(subject.system_distribution).to be_nil
    end

    it "handles null operating system" do
      FactoryBot.create(:computer_system, :managed_entity => subject)
      expect(subject.system_distribution).to be_nil
    end

    it "delegates value" do
      os = FactoryBot.create(:operating_system, :distribution => "coreos")
      FactoryBot.create(:computer_system, :managed_entity => subject, :operating_system => os)
      expect(subject.system_distribution).to eq("coreos")
    end
  end

  describe "#kernel_version" do # on os
    it "handles null computer system" do
      expect(subject.kernel_version).to be_nil
    end

    it "handles null operating system" do
      FactoryBot.create(:computer_system, :managed_entity => subject)
      expect(subject.kernel_version).to be_nil
    end

    it "delegates value" do
      os = FactoryBot.create(:operating_system, :kernel_version => "1.0.0")
      FactoryBot.create(:computer_system, :managed_entity => subject, :operating_system => os)
      expect(subject.kernel_version).to eq("1.0.0")
    end
  end
end
