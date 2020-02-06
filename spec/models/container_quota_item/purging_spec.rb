RSpec.describe ContainerQuotaItem do
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
        @old_quota_old_item        = FactoryBot.create(:container_quota_item, :container_quota => @old_quota,
                                                                               :deleted_on      => deleted_date - 1.day)
        @old_quota_purge_date_item = FactoryBot.create(:container_quota_item, :container_quota => @old_quota,
                                                                               :deleted_on      => deleted_date)
        @old_quota_new_item        = FactoryBot.create(:container_quota_item, :container_quota => @old_quota,
                                                                               :deleted_on      => deleted_date + 1.day)

        # Quota items may get archived as result of quota edits, while parent quota remains active.
        @active_quota = FactoryBot.create(:container_quota, :deleted_on => nil)
        @active_quota_scope = FactoryBot.create(:container_quota_scope, :container_quota => @active_quota)
        @active_quota_old_item        = FactoryBot.create(:container_quota_item, :container_quota => @active_quota,
                                                                                  :deleted_on      => deleted_date - 1.day)
        @active_quota_purge_date_item = FactoryBot.create(:container_quota_item, :container_quota => @active_quota,
                                                                                  :deleted_on      => deleted_date)
        @active_quota_new_item        = FactoryBot.create(:container_quota_item, :container_quota => @active_quota,
                                                                                  :deleted_on      => deleted_date + 1.day)
        @active_quota_active_item     = FactoryBot.create(:container_quota_item, :container_quota => @active_quota,
                                                                                  :deleted_on      => nil)
      end

      def assert_unpurged_ids(model, unpurged_ids)
        expect(model.order(:id).pluck(:id)).to eq(Array(unpurged_ids).sort)
      end

      it "purge_date and older" do
        described_class.purge(deleted_date)
        # @old_quota is itself due for purging, but not as part of ContainerQuotaItem::Purging.
        assert_unpurged_ids(ContainerQuota, [@old_quota.id, @active_quota.id])
        assert_unpurged_ids(ContainerQuotaScope, [@old_quota_scope.id, @active_quota_scope.id])
        assert_unpurged_ids(ContainerQuotaItem, [@old_quota_new_item.id, @active_quota_new_item.id, @active_quota_active_item.id])
      end

      it "with a window" do
        described_class.purge(deleted_date, 1)
        # @old_quota is itself due for purging, but not as part of ContainerQuotaItem::Purging.
        assert_unpurged_ids(ContainerQuota, [@old_quota.id, @active_quota.id])
        assert_unpurged_ids(ContainerQuotaScope, [@old_quota_scope.id, @active_quota_scope.id])
        assert_unpurged_ids(ContainerQuotaItem, [@old_quota_new_item.id, @active_quota_new_item.id, @active_quota_active_item.id])
      end
    end
  end
end
