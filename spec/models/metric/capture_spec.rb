describe Metric::Capture do
  let(:zone) { FactoryGirl.create(:zone) }
  let(:ems) { FactoryGirl.create(:ems_vmware) }
  let(:ems2)  { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:ems3) { FactoryGirl.create(:ems_vmware, :zone => zone) }

  describe ".perf_collect_all_metrics_queue" do
    it "submits with options" do
      expect_queued(
        :class_name  => "Metric::Capture",
        :method_name => "perf_collect_all_metrics",
        :args        => [ems.id, "realtime", nil, nil, :exclude_storage => true],
        :zone        => ems.zone_name
      )

      Metric::Capture.perf_collect_all_metrics_queue([ems], "realtime", nil, nil, :exclude_storage => true)
    end

    it "submits multiple ems" do
      ems2 # other ems is not used

      expect_queued(
        :class_name  => "Metric::Capture",
        :method_name => "perf_collect_all_metrics",
        :args        => [ems.id, "realtime", nil, nil, {}],
      )
      expect_queued(
        :class_name  => "Metric::Capture",
        :method_name => "perf_collect_all_metrics",
        :args        => [ems2.id, "realtime", nil, nil, {}],
      )

      Metric::Capture.perf_collect_all_metrics_queue([ems, ems2], "realtime")
    end
  end

  describe ".perf_capture_gap_queue" do
    context "with default zone" do
      it "queues ems" do
        EvmSpecHelper.local_miq_server
        ems  # default zone is used
        ems2
        ems3

        expect_queued(
          :class_name  => "Metric::Capture",
          :method_name => "perf_collect_all_metrics",
          :args        => [ems.id, "historical", nil, nil, :exclude_storages => true],
        )
        Metric::Capture.perf_capture_gap_queue(nil, nil)
      end
    end

    context "with a zone.id" do
      it "queues multiple ems" do
        ems
        ems2 # zone declared is used
        ems3

        expect_queued(
          :class_name  => "Metric::Capture",
          :method_name => "perf_collect_all_metrics",
          :args        => [ems2.id, "historical", nil, nil, :exclude_storages => true],
        )
        expect_queued(
          :class_name  => "Metric::Capture",
          :method_name => "perf_collect_all_metrics",
          :args        => [ems3.id, "historical", nil, nil, :exclude_storages => true],
        )
        Metric::Capture.perf_capture_gap_queue(nil, nil, zone.id)
      end
    end

    context "with an ems" do
      it "queues an ems" do
        expect_queued(
          :class_name  => "Metric::Capture",
          :method_name => "perf_collect_all_metrics",
          :args        => [ems.id, "historical", nil, nil, :exclude_storages => true],
        )
        Metric::Capture.perf_capture_gap_queue(nil, nil, ems)
      end
    end
  end

  def expect_queued(args)
    expect(MiqQueue).to receive(:put_unless_exists).with(hash_including(args))
  end
end
