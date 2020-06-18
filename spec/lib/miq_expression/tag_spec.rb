RSpec.describe MiqExpression::Tag do
  describe ".tag_path_with" do
    it "returns correct path" do
      target = described_class.parse('Vm.managed-amazon:vm:name')
      expect(target.tag_path_with('mapped:smartstate')).to eq("/managed/amazon:vm:name/mapped:smartstate")
    end
  end

  describe ".parse" do
    it "with model.managed-amazon" do
      tag = "Vm.managed-amazon:vm:name"
      expect(described_class.parse(tag)).to have_attributes(:model        => Vm,
                                                            :associations => [],
                                                            :namespace    => "/managed/amazon:vm:name")
    end

    it "with model.managed-in_tag" do
      tag = "Vm.managed-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => Vm,
                                                            :associations => [],
                                                            :namespace    => "/managed/service_level")
    end

    it "with model.managed-in_tag" do
      tag = "Vm.managed-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => Vm,
                                                            :associations => [],
                                                            :namespace    => "/managed/service_level")
    end

    it "with model.managed-in_tag" do
      tag = "Vm.managed-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => Vm,
                                                            :associations => [],
                                                            :namespace    => "/managed/service_level")
    end

    it "with model.last.managed-in_tag" do
      tag = "Vm.host.managed-environment"
      expect(described_class.parse(tag)).to have_attributes(:model        => Vm,
                                                            :associations => ['host'],
                                                            :namespace    => "/managed/environment")
    end

    it "with model.managed-in_tag" do
      tag = "Vm.managed-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => Vm,
                                                            :associations => [],
                                                            :namespace    => "/managed/service_level")
    end

    it "with model-parent::model.managed-in_tag" do
      tag = "ManageIQ::Providers::CloudManager.managed-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => ManageIQ::Providers::CloudManager,
                                                            :associations => [],
                                                            :namespace    => "/managed/service_level")
    end

    it "with model.associations.associations.managed-in_tag" do
      tag = "Vm.service.user.managed-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => Vm,
                                                            :associations => %w(service user),
                                                            :namespace    => "/managed/service_level")
    end

    it "with model.associations.managed-in_tag" do
      tag = "Service.user.managed-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => Service,
                                                            :associations => ['user'],
                                                            :namespace    => "/managed/service_level")
    end

    it "with model.associations.user_tag-in_tag" do
      tag = "Service.user.user_tag-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => Service,
                                                            :associations => ['user'],
                                                            :namespace    => "/user/service_level")
    end

    it "with invalid case model.associations.managed-in_tag" do
      tag = "Service.user.mXaXnXaXged-service_level"
      expect(described_class.parse(tag)).to be_nil
    end

    it "supports managed-tag (no model)" do
      tag = "managed-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => nil,
                                                            :associations => [],
                                                            :namespace    => "/managed/service_level")
    end

    it "returns nil with invalid case managed" do
      tag = "managed"
      expect(described_class.parse(tag)).to be_nil
    end

    it "returns nil with invalid case model.managed" do
      tag = "Vm.managed"
      expect(described_class.parse(tag)).to be_nil
    end

    it "returns nil with invalid case parent-model::model::somethingmanaged-se" do
      tag = "ManageIQ::Providers::CloudManagermanaged-se"
      expect(described_class.parse(tag)).to be_nil
    end

    it "can parse models in deeply nested namespaces" do
      tag = "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem.managed-cc"

      expected = {
        :model => ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem
      }
      expect(described_class.parse(tag)).to have_attributes(expected)
    end
  end

  describe "#to_s" do
    it "renders tags in string form" do
      tag = described_class.new("Vm", [], "environment")
      expect(tag.to_s).to eq("Vm.managed-environment")
    end

    it "can handle model-less tags" do
      tag = described_class.new(nil, [], "environment")
      expect(tag.to_s).to eq("managed-environment")
    end

    it "can handle associations" do
      tag = described_class.new("Vm", ["host"], "environment")
      expect(tag.to_s).to eq("Vm.host.managed-environment")
    end
  end

  describe '#report_column' do
    it 'returns the correct format for a tag' do
      tag = MiqExpression::Tag.parse('Vm.managed-environment')
      expect(tag.report_column).to eq('managed.environment')
    end
  end

  describe "#column_type" do
    it "is always a string" do
      expect(described_class.new(Vm, [], "host").column_type).to eq(:string)
    end
  end

  describe "#numeric?" do
    it "is never numeric" do
      expect(described_class.new(Vm, [], "host")).not_to be_numeric
    end
  end

  describe "#sub_type" do
    it "is always a string" do
      expect(described_class.new(Vm, [], "host").sub_type).to eq(:string)
    end
  end

  describe "#attribute_supported_by_sql?" do
    it "is always false" do
      expect(described_class.new(Vm, [], "host")).not_to be_attribute_supported_by_sql
    end
  end
end
