RSpec.describe MiqExpression::Tag do
  describe '#report_column' do
    it 'returns the correct format for a tag' do
      tag = MiqExpression::Tag.parse('Vm.managed-environment')
      expect(tag.report_column).to eq('managed.environment')
    end
  end
end
