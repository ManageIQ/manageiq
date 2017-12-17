RSpec.describe MiqExpression::CountField do
  describe '.parse' do
    it 'parses field model.has_many_associations with valid format' do
      count_field = 'Vm.disks'
      expect(described_class.parse(count_field)).to have_attributes(:model        => Vm,
                                                                    :associations => ['disks'])
    end

    it 'doesn\'t parse field model.belongs_to_associations with invalid format' do
      count_field = 'Vm.host'
      expect(described_class.parse(count_field)).to be_nil
    end

    it 'doesn\'t parse field with format of MiqExpression::Field::REGEX' do
      count_field = 'Vm.host-name'
      expect(described_class.parse(count_field)).to be_nil
    end

    it 'doesn\'t parse field with format of  MiqExpression::Tag::REGEX' do
      count_field = 'Vm.managed-service_level'
      expect(described_class.parse(count_field)).to be_nil
    end

    it 'doesn\'t parse field with invalid format' do
      count_field = 'sdfsdf.host'
      expect(described_class.parse(count_field)).to be_nil
    end
  end

  describe "#to_s" do
    it "renders count fields in string form" do
      count_field = described_class.new(Vm, ["disks"])
      expect(count_field.to_s).to eq("Vm.disks")
    end

    it "can handle multiple associations" do
      count_field = described_class.new(Vm, %w(hardware disks))
      expect(count_field.to_s).to eq("Vm.hardware.disks")
    end
  end
end
