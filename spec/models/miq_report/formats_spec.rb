describe MiqReport::Formats do
  describe '.default_format_details_for' do
    let(:human_mb_details) do
      { :description => 'Suffixed Megabytes (MB, GB)',
        :columns     => nil,
        :sub_types   => [:megabytes],
        :function    => {:name => 'mbytes_to_human_size'},
        :precision   => 1 }
    end

    it 'returns human MB format details for memory_mb' do
      expect(described_class.default_format_details_for('memory_mb', 'memory_mb', :integer)).to eq(human_mb_details)
    end

    it 'returns human MB format details for computer_system_hardware.memory_mb' do
      expect(described_class.default_format_details_for('Hardware-memory_mb', 'computer_system.hardware.memory_mb', :integer)).to eq(human_mb_details)
    end
  end

  describe '.default_format_for' do
    context 'for chargebacks' do
      let(:columns) { Chargeback.descendants.collect(&:virtual_attributes_to_define).inject({}, &:merge) }
      it 'works' do
        columns.each do |name, datatype|
          name = ChargebackVm.default_column_for_format(name)
          subj = described_class.default_format_for(name.to_sym, name.to_sym, datatype.first)
          if name.ends_with?('_cost')
            expect(subj).to eq(:currency_precision_2)
          elsif name.ends_with?('_metric')
            expect(subj).not_to be_nil
          end

          unless subj.nil?
            options = described_class.available_formats_for(name.to_sym, name, datatype.first)
            expect(options.keys).to include(subj)
          end
        end
      end
    end
  end
end
