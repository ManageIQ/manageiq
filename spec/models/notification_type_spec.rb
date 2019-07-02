describe NotificationType, :type => :model do
  describe '.seed' do
    it 'has not seeded records before seed is run' do
      expect(described_class.count).to be_zero
    end

    context 'after the seed is run' do
      before { described_class.seed }
      it 'has added rows' do
        expect(described_class.count).to be > 0
      end

      it 'can be run again without any effects' do
        expect { described_class.seed }.not_to change(described_class, :count)
      end
    end
  end

  describe '#subscribers_ids' do
    let(:user1) { FactoryBot.create(:user) }
    let(:tenant) { FactoryBot.create(:tenant) }
    let!(:user2) { FactoryBot.create(:user_with_group, :tenant => tenant) }
    let(:vm) { FactoryBot.create(:vm, :tenant => tenant) }

    context 'global notification type' do
      let(:notification) { FactoryBot.create(:notification_type, :audience => 'global') }
      it 'returns all the users' do
        expect(notification.subscriber_ids(vm, user1)).to match_array(User.pluck(:id))
      end
    end

    context 'user specific notification type' do
      let(:notification) { FactoryBot.create(:notification_type, :audience => 'user') }
      it 'returns just the user, who initiated the task' do
        expect(notification.subscriber_ids(vm, user1)).to match_array([user1.id])
      end
    end

    context 'tenant specific notification type' do
      let(:notification) { FactoryBot.create(:notification_type, :audience => 'tenant') }
      it 'returns the users in the tenant same tenant as concerned vm' do
        expect(notification.subscriber_ids(vm, user1)).to match_array([user2.id])
      end

      it "returns single id if user belongs to different group" do
        user2.miq_groups << FactoryBot.create(:miq_group, :tenant => tenant)
        expect(notification.subscriber_ids(vm, user1)).to match_array([user2.id])
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
