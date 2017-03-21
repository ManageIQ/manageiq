require "rails_helper"

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
end
