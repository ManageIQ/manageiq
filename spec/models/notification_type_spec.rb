RSpec.describe NotificationType, :type => :model do
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
    let(:user1)  { FactoryBot.create(:user) }
    let!(:user2) { FactoryBot.create(:user_with_group, :tenant => tenant) }
    let(:tenant) { FactoryBot.create(:tenant) }
    let(:vm)     { FactoryBot.create(:vm, :tenant => tenant) }

    it 'returns all the users for a global notification type' do
      type = FactoryBot.create(:notification_type, :audience => 'global')
      expect(type.subscriber_ids(vm, user1)).to match_array(User.pluck(:id))
    end

    it 'returns just the user who initiated the task for a user specific notification type' do
      type = FactoryBot.create(:notification_type, :audience => 'user')
      expect(type.subscriber_ids(vm, user1)).to match_array([user1.id])
    end

    context 'tenant specific notification type' do
      let(:type) { FactoryBot.create(:notification_type, :audience => 'tenant') }
      it 'returns the users in the tenant same tenant as concerned vm' do
        expect(type.subscriber_ids(vm, user1)).to match_array([user2.id])
      end

      it "returns single id if user belongs to different group" do
        user2.miq_groups << FactoryBot.create(:miq_group, :tenant => tenant)
        expect(type.subscriber_ids(vm, user1)).to match_array([user2.id])
      end
    end

    context "with seeded types" do
      before { described_class.seed }

      it "returns an array for all types without a subject" do
        described_class.all.each do |type|
          ids = type.subscriber_ids(nil, user1)
          expect(ids).to be_an_instance_of(Array), "expected an array for notification type #{type.name}, got #{ids.inspect}"
        end
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
