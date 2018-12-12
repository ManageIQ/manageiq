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

  describe '#subscribers_ids' do
    let(:user1) { FactoryBot.create(:user) }
    let(:tenant2) { FactoryBot.create(:tenant) }
    let!(:user2) { FactoryBot.create(:user_with_group, :tenant => tenant2) }
    let(:vm) { FactoryBot.create(:vm, :tenant => tenant2) }
    subject { notification.subscriber_ids(vm, user1) }
    context 'global notification type' do
      let(:notification) { FactoryBot.create(:notification_type, :audience => 'global') }
      it 'returns all the users' do
        is_expected.to match_array(User.pluck(:id))
      end
    end

    context 'user specific notification type' do
      let(:notification) { FactoryBot.create(:notification_type, :audience => 'user') }
      it 'returns just the user, who initiated the task' do
        is_expected.to match_array([user1.id])
      end
    end

    context 'tenant specific notification type' do
      let(:notification) { FactoryBot.create(:notification_type, :audience => 'tenant') }
      it 'returns the users in the tenant same tenant as concerned vm' do
        is_expected.to match_array([user2.id])
      end
      it "returns single id if user belongs to different group" do
        user2.miq_groups << FactoryBot.create(:miq_group, :tenant => tenant2)
        is_expected.to match_array([user2.id])
      end
    end
  end

  describe "#enabled?" do
    it "detects properly" do
      expect(FactoryBot.build(:notification_type, :audience => NotificationType::AUDIENCE_USER)).to be_enabled
      expect(FactoryBot.build(:notification_type, :audience => NotificationType::AUDIENCE_NONE)).not_to be_enabled
      expect(FactoryBot.build(:notification_type, :audience => NotificationType::AUDIENCE_NONE)).to be_valid
    end
  end
end
