RSpec.describe MiqExpression::Tag do
  describe ".parse" do
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

    it "with model.associations.associations.managed-in_tag" do
      tag = "Vm.service.user.managed-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => Vm,
                                                            :associations => %w(service user),
                                                            :namespace    => "/managed/service_level")
    end

    it "with model.associations.managed-in_tag" do
      tag = "service.user.managed-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => Service,
                                                            :associations => ['user'],
                                                            :namespace    => "/managed/service_level")
    end

    it "with model.associations.user_tag-in_tag" do
      tag = "service.user.user_tag-service_level"
      expect(described_class.parse(tag)).to have_attributes(:model        => Service,
                                                            :associations => ['user'],
                                                            :namespace    => "/user/service_level")
    end

    it "with invalid case model.associations.managed-in_tag" do
      tag = "service.user.mXaXnXaXged-service_level"
      expect(described_class.parse(tag)).to be_nil
    end

    it "returns nil with invalid case managed-tag" do
      tag = "managed-service_level"
      expect(described_class.parse(tag)).to be_nil
    end

    it "returns nil with invalid case managed" do
      tag = "managed"
      expect(described_class.parse(tag)).to be_nil
    end

    it "returns nil with invalid case model.managed" do
      tag = "Vm.managed"
      expect(described_class.parse(tag)).to be_nil
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
      expect(described_class.new(Vm, [], "/host").column_type).to eq(:string)
    end
  end

  describe "#numeric?" do
    it "is never numeric" do
      expect(described_class.new(Vm, [], "/host")).not_to be_numeric
    end
  end

  describe "#sub_type" do
    it "is always a string" do
      expect(described_class.new(Vm, [], "/host").sub_type).to eq(:string)
    end
  end

  describe "#attribute_supported_by_sql?" do
    it "is always false" do
      expect(described_class.new(Vm, [], "/host")).not_to be_attribute_supported_by_sql
    end
  end
end
