describe NotificationType, :type => :model do
  describe '.seed' do
    subject { described_class.count }
    context 'before the seed is run' do
      it { is_expected.to be_zero }
    end
    context 'after the seed is run' do
      before { described_class.seed }
      it { is_expected.to be > 0 }
      it 'can be run again without any effects' do
        expect { described_class.seed }.not_to change(described_class, :count)
      end
    end
  end
end
