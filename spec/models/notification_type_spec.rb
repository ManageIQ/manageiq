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
    let(:user1) { FactoryGirl.create(:user) }
    let(:tenant2) { FactoryGirl.create(:tenant) }
    let!(:user2) { FactoryGirl.create(:user_with_group, :tenant => tenant2) }
    let(:vm) { FactoryGirl.create(:vm, :tenant => tenant2) }
    subject { notification.subscriber_ids(vm, user1) }
    context 'global notification type' do
      let(:notification) { FactoryGirl.create(:notification_type, :audience => 'global') }
      it 'returns all the users' do
        is_expected.to match_array(User.pluck(:id))
      end
    end

    context 'user specific notification type' do
      let(:notification) { FactoryGirl.create(:notification_type, :audience => 'user') }
      it 'returns just the user, who initiated the task' do
        is_expected.to match_array([user1.id])
      end
    end

    context 'tenant specific notification type' do
      let(:notification) { FactoryGirl.create(:notification_type, :audience => 'tenant') }
      it 'returns the users in the tenant same tenant as concerned vm' do
        is_expected.to match_array([user2.id])
      end
      it "returns single id if user belongs to different group" do
        user2.miq_groups << FactoryGirl.create(:miq_group, :tenant => tenant2)
        is_expected.to match_array([user2.id])
      end
    end
  end
end
