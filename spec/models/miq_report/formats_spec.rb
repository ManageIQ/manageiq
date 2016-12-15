describe MiqReport::Formats do
  describe '.default_format_for' do
    context 'for chargebacks' do
      let(:columns) { Chargeback.descendants.collect(&:virtual_attributes_to_define).inject({}, &:merge) }
      it 'works' do
        columns.each do |name, datatype|
          subj = described_class.default_format_for(name.to_sym, name.to_sym, datatype.first)
          if name.ends_with?('_cost')
            expect(subj).to eq(:currency_precision_2)
          elsif name.ends_with?('_metric')
            expect(subj).not_to be_nil
          end
        end
      end
    end
  end
end
