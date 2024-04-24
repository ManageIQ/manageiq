RSpec.describe ManageIQ::Providers::ContainerManager::MetricsCapture do
  include Spec::Support::MetricHelper
  include Spec::Support::SupportsHelper

  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:ems)        { FactoryBot.create(:ems_container, :zone => miq_server.zone) }

  describe "#perf_capture_all_queue" do
    context "with a provider not supporting metrics capture" do
      before { stub_supports_not(ems, :metrics) }

      it "doesn't queue any targets captures" do
        ems.perf_capture_object.perf_capture_all_queue

        expect(queue_timings).to be_empty
      end
    end

    context "with a provider supporting metrics capture" do
      before { stub_supports(ems, :metrics) }

      context "with no inventory" do
        it "doesn't queue any targets captures" do
          ems.perf_capture_object.perf_capture_all_queue

          expect(queue_timings).to be_empty
        end
      end

      context "with inventory" do
        let(:ems)              { FactoryBot.create(:ems_container, :with_metrics_endpoint, :zone => miq_server.zone) }
        let(:deleted_on)       { nil }
        let!(:container_node)  { FactoryBot.create(:container_node, :ext_management_system => ems, :deleted_on => deleted_on) }
        let!(:container_group) { FactoryBot.create(:container_group, :ext_management_system => ems, :deleted_on => deleted_on) }
        let!(:container)       { FactoryBot.create(:container, :ext_management_system => ems, :deleted_on => deleted_on) }
        let!(:container_image) { FactoryBot.create(:container_image, :ext_management_system => ems, :deleted_on => deleted_on) }

        context "that doesn't support capture" do
          it "doesn't queue any targets captures" do
            ems.perf_capture_object.perf_capture_all_queue

            expect(queue_timings).to be_empty
          end
        end

        context "that supports capture" do
          before do
            stub_supports(container_node, :capture)
            stub_supports(container_group, :capture)
            stub_supports(container, :capture)
            stub_supports(container_image, :capture)
          end

          it "queues capture for targets" do
            ems.perf_capture_object.perf_capture_all_queue

            expect(queue_timings).to include(
              "realtime" => {
                queue_object(container_node)  => [[]],
                queue_object(container_group) => [[]],
                queue_object(container)       => [[]],
                queue_object(container_image) => [[]]
              }
            )
          end

          context "that are all archived" do
            let(:deleted_on) { Metric::Targets.targets_archived_from - 1.hour }

            it "doesn't queue any targets captures" do
              ems.perf_capture_object.perf_capture_all_queue

              expect(queue_timings).to be_empty
            end
          end
        end
      end
    end
  end
end
