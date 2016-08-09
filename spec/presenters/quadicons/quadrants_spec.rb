describe Quadicons::Quadrants, :type => :helper do
  let(:record) { FactoryGirl.build(:vm_redhat) }
  let(:kontext) { Quadicons::Context.new(helper) }

  describe '#quadrantize' do
    subject(:quadrant) do
      Quadicons::Quadrants.quadrantize(:guest_count, record, kontext)
    end

    it 'Finds a constant and returns an instance of it' do
      expect(subject).to be_a_kind_of(Quadicons::Quadrants::GuestCount)
    end
  end
end
