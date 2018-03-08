describe Notification do
  context "::Purging" do
    describe "purge_scope" do
      # Defined at the bottom
      before { seed_notification_types_and_users }

      let(:type_1_day)  { NotificationType.where(:name => "1 day").first }
      let(:type_7_day)  { NotificationType.where(:name => "7 days").first }
      let(:type_14_day) { NotificationType.where(:name => "14 days").first }

      it "creates a query for every notification_type expire_in value" do
        Timecop.freeze(Time.current) do
          expected_sql = <<-SQL.lines.map(&:strip).join(" ")
            SELECT "notifications".*
            FROM "notifications"
            INNER JOIN "notification_types" ON "notification_types"."id" = "notifications"."notification_type_id"
            WHERE (notifications.created_at + notification_types.expires_in * INTERVAL '1 second' < now())
          SQL

          expect(described_class.purge_scope(nil).to_sql).to eq(expected_sql)
        end
      end
    end

    describe ".purge_by_date" do
      # Defined at the bottom
      before { seed_notification_types_and_users }

      let(:notification_type) { NotificationType.where(:name => type_name).first }
      let(:new_notification) do
        FactoryGirl.create(:notification, :notification_type => notification_type)
      end

      let(:semi_old_notification) do
        Timecop.freeze(notification_type.expires_in.seconds.ago + 6.hours) do
          FactoryGirl.create(:notification, :notification_type => notification_type)
        end
      end

      let(:old_notification) do
        Timecop.freeze(notification_type.expires_in.seconds.ago - 6.hours) do
          FactoryGirl.create(:notification, :notification_type => notification_type)
        end
      end

      context "for 24.hour notification types" do
        let(:type_name) { "1 day" }

        it "purges notifications older than a day" do
          expect(described_class.all).to match_array([new_notification, semi_old_notification, old_notification])
          expect(NotificationRecipient.count).to eq(6)
          count = described_class.purge_by_date(described_class.purge_date)
          expect(described_class.all).to match_array([new_notification, semi_old_notification])
          expect(NotificationRecipient.count).to eq(4)
          expect(count).to eq(1)
        end
      end

      context "for 7.day notification types" do
        let(:type_name) { "7 days" }

        it "purges notifications older than a week" do
          expect(described_class.all).to match_array([new_notification, semi_old_notification, old_notification])
          expect(NotificationRecipient.count).to eq(6)
          count = described_class.purge_by_date(described_class.purge_date)
          expect(described_class.all).to match_array([new_notification, semi_old_notification])
          expect(NotificationRecipient.count).to eq(4)
          expect(count).to eq(1)
        end
      end

      context "for 14.day notification types" do
        let(:type_name) { "14 days" }

        it "purges notifications older than two weeks" do
          expect(described_class.all).to match_array([new_notification, semi_old_notification, old_notification])
          expect(NotificationRecipient.count).to eq(6)
          count = described_class.purge_by_date(described_class.purge_date)
          expect(described_class.all).to match_array([new_notification, semi_old_notification])
          expect(NotificationRecipient.count).to eq(4)
          expect(count).to eq(1)
        end
      end

      context "for mixed notification types" do
        # Using the existing let for this type, "7 days" and "14 days" will be
        # built custom for this test.
        let(:type_name)   { "1 day" }
        let(:type_7_day)  { NotificationType.where(:name => "7 days").first }
        let(:type_14_day) { NotificationType.where(:name => "14 days").first }

        let(:new_7_day_notification) do
          FactoryGirl.create(:notification, :notification_type => type_7_day)
        end

        let(:new_14_day_notification) do
          FactoryGirl.create(:notification, :notification_type => type_7_day)
        end

        let(:old_7_day_notification) do
          Timecop.freeze(type_7_day.expires_in.seconds.ago - 6.hours) do
            FactoryGirl.create(:notification, :notification_type => type_7_day)
          end
        end

        let(:old_14_day_notification) do
          Timecop.freeze(type_14_day.expires_in.seconds.ago - 6.hours) do
            FactoryGirl.create(:notification, :notification_type => type_14_day)
          end
        end

        let(:all_notifcations) do
          [
            new_notification,
            semi_old_notification,
            old_notification,
            new_7_day_notification,
            old_7_day_notification,
            new_14_day_notification,
            old_14_day_notification
          ]
        end

        let(:kept_notifcations) do
          [
            new_notification,
            semi_old_notification,
            new_7_day_notification,
            new_14_day_notification
          ]
        end

        it "purges notifications older than two weeks" do
          expect(described_class.all).to match_array(all_notifcations)
          expect(NotificationRecipient.count).to eq(14)
          count = described_class.purge_by_date(described_class.purge_date)
          expect(described_class.all).to match_array(kept_notifcations)
          expect(NotificationRecipient.count).to eq(8)
          expect(count).to eq(3)
        end
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

    def seed_notification_types_and_users
      # Seed different notification types
      [1.day, 7.days, 14.days].each do |expire|
        type_attrs = {
          :name       => expire.inspect, # example: "1 day"
          :audience   => NotificationType::AUDIENCE_GLOBAL,
          :expires_in => expire.to_i
        }
        FactoryGirl.create(:notification_type, type_attrs)
      end

      # Create some recipients
      FactoryGirl.create(:user)
      FactoryGirl.create(:user)
    end
  end
end
