describe MiqReport do
  context 'Formatting' do
    context '#mhz_to_human_size' do
      let(:report) { MiqReport.new }
      it 'takes precision as argument' do
        expect(report.format_mhz_to_human_size(1234, :precision => 2)).to eq('1.23 GHz')
      end
      it 'works with default precision' do
        expect(report.format_mhz_to_human_size(1234)).to eq('1.2 GHz')
      end
      it 'applies cool prefix' do
        expect(report.format_mhz_to_human_size(-1234, :prefix => 'cool')).to eq('cool-1.2 GHz')
      end
      it 'applies hot suffix' do
        expect(report.format_mhz_to_human_size(1234, :suffix => 'hot')).to eq('1.2 GHzhot')
      end
    end
  end
end
