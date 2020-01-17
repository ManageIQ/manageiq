RSpec.describe ContainerQuota do
  context "::Purging" do
    context ".purge_queue" do
      before do
        EvmSpecHelper.create_guid_miq_server_zone
      end
      let(:purge_time) { (Time.zone.now + 10).round }

      it "submits to the queue" do
        expect(described_class).to receive(:purge_date).and_return(purge_time)
        described_class.purge_timer

        q = MiqQueue.all
        expect(q.length).to eq(1)
        expect(q.first).to have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge_by_date",
          :args        => [purge_time]
        )
      end
    end

    context ".purge" do
      let(:deleted_date) { 6.months.ago }

      before do
        @old_quota = FactoryBot.create(:container_quota, :deleted_on => deleted_date - 1.day)
        @old_quota_scope = FactoryBot.create(:container_quota_scope, :container_quota => @old_quota)
        @old_quota_old_item    = FactoryBot.create(:container_quota_item, :container_quota => @old_quota,
                                                                           :deleted_on      => deleted_date - 1.day)
        @old_quota_active_item = FactoryBot.create(:container_quota_item, :container_quota => @old_quota,
                                                                           :deleted_on      => nil)

        @purge_date_quota = FactoryBot.create(:container_quota, :deleted_on => deleted_date)

        @new_quota = FactoryBot.create(:container_quota, :deleted_on => deleted_date + 1.day)
        @new_quota_scope = FactoryBot.create(:container_quota_scope, :container_quota => @new_quota)
        @new_quota_old_item = FactoryBot.create(:container_quota_item, :container_quota => @new_quota,
                                                                        :deleted_on      => deleted_date - 1.day)
      end

      def assert_unpurged_ids(model, unpurged_ids)
        expect(model.order(:id).pluck(:id)).to eq(Array(unpurged_ids).sort)
      end

      it "purge_date and older" do
        described_class.purge(deleted_date)
        assert_unpurged_ids(ContainerQuota, @new_quota.id)
        assert_unpurged_ids(ContainerQuotaScope, @new_quota_scope.id)
        # This quota item is itself due for purging, but not as part of ContainerQuota::Purging.
        assert_unpurged_ids(ContainerQuotaItem, @new_quota_old_item.id)
      end

      it "with a window" do
        described_class.purge(deleted_date, 1)
        assert_unpurged_ids(ContainerQuota, @new_quota.id)
        assert_unpurged_ids(ContainerQuotaScope, @new_quota_scope.id)
        # This quota item is itself due for purging, but not as part of ContainerQuota::Purging.
        assert_unpurged_ids(ContainerQuotaItem, @new_quota_old_item.id)
      end
    end
  end
end
