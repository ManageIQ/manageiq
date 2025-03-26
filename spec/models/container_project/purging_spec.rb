RSpec.describe ContainerProject do
  context "::Purging" do
    context ".purge_queue" do
      before do
        EvmSpecHelper.local_miq_server
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
      let(:new_container_project) { FactoryBot.create(:container_project, :deleted_on => deleted_date + 1.day) }

      before do
        @old_container_project = FactoryBot.create(:container_project, :deleted_on => deleted_date - 1.day)
        FactoryBot.create(:container_project, :deleted_on => deleted_date)
        new_container_project
      end

      def assert_unpurged_ids(unpurged_ids)
        expect(described_class.order(:id).pluck(:id)).to match_array(unpurged_ids.sort)
      end

      it "purge_date and older" do
        described_class.purge(deleted_date)
        assert_unpurged_ids([new_container_project.id])
      end

      it "with a window" do
        described_class.purge(deleted_date, 1)
        assert_unpurged_ids([new_container_project.id])
      end

      it "purges associated rows" do
        @old_container_project.miq_alert_statuses << FactoryBot.create(:miq_alert_status)
        described_class.purge(deleted_date)
        expect(@old_container_project.miq_alert_statuses.count).to eq(0)
      end
    end
  end
end
