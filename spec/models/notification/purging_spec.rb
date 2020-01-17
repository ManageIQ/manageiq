RSpec.describe Notification do
  context "::Purging" do
    describe ".purge_by_date" do
      it "purges old notifications" do
        FactoryBot.create(:user)
        FactoryBot.create(:user)
        type = FactoryBot.create(:notification_type, :audience => NotificationType::AUDIENCE_GLOBAL)

        # Notification and recipients that will not be purged
        new_notification = FactoryBot.create(:notification, :notification_type => type)

        old_notification, semi_old_notification = nil
        Timecop.freeze(6.days.ago) do
          semi_old_notification = FactoryBot.create(:notification, :notification_type => type)
        end

        Timecop.freeze(8.days.ago) do
          # Notification and recipients that will be purged
          old_notification = FactoryBot.create(:notification, :notification_type => type)
        end

        expect(described_class.all).to match_array([new_notification, semi_old_notification, old_notification])
        expect(NotificationRecipient.count).to eq(6)
        count = described_class.purge_by_date(described_class.purge_date)
        expect(described_class.all).to match_array([new_notification, semi_old_notification])
        expect(NotificationRecipient.count).to eq(4)
        expect(count).to eq(1)
      end
    end

    describe ".purge_timer" do
      it "queues the correct purge method" do
        EvmSpecHelper.local_miq_server
        described_class.purge_timer
        q = MiqQueue.first
        expect(q).to have_attributes(:class_name => described_class.name, :method_name => "purge_by_date")
      end
    end
  end
end
