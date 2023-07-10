RSpec.describe Metric::CiMixin::StateFinders do
  let(:image) { FactoryBot.create(:container_image) }
  let(:container1) { FactoryBot.create(:container, :container_image => image) }
  let(:container2) { FactoryBot.create(:container, :container_image => image) }
  let(:node1) { FactoryBot.create(:container_node) }
  let(:node2) { FactoryBot.create(:container_node) }

  let(:ts_now) { Time.now.utc.beginning_of_hour.to_s }
  let(:timestamp) { 2.hours.ago.utc.beginning_of_hour.to_s }

  # NOTE: in these specs, we could let perf_capture_state be called
  # but using this reduces the queries
  describe "#vim_performance_state_for_ts" do
    let(:vps_now) { create_vps(image, ts_now) }
    let(:vps) { create_vps(image, timestamp) }

    context "when no cache" do
      it "creates new value when one is not found in the database" do
        expect(image).to receive(:perf_capture_state).once.and_return(vps_now)

        expect do
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps_now)
        end.to make_database_queries(:count => 1)

        # reuses cached / created value
        expect do
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps_now)
        end.not_to make_database_queries
      end

      it "caches the newly created value" do
        expect(image).to receive(:perf_capture_state).once.and_return(vps_now)

        image.vim_performance_state_for_ts(timestamp)
        expect do
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps_now)
        end.not_to make_database_queries
      end
    end

    # ci_mixin/processing.rb uses this
    context "when using preload_vim_performance_state_for_ts_iso8601" do
      it "finds cached value" do
        vps_now
        vps
        image.preload_vim_performance_state_for_ts_iso8601(:timestamp => [ts_now, timestamp])
        expect(image).to receive(:perf_capture_state).never

        expect do
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps_now) # TODO: should be vps
        end.to make_database_queries(:count => 0)
      end

      it "falls back to cached now" do
        vps_now
        image.preload_vim_performance_state_for_ts_iso8601(:timestamp => [ts_now, timestamp])
        expect(image).to receive(:perf_capture_state).never

        expect do
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps_now)
        end.not_to make_database_queries
      end

      it "creates (and caches) a value when now isn't cached" do
        image.preload_vim_performance_state_for_ts_iso8601(:timestamp => [])
        expect(image).to receive(:perf_capture_state).once.and_return(vps_now)

        # NOTE: this performs a query because the back end does not know if this
        # value was searched and not found, or no caching was performed
        expect do
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps_now)
        end.to make_database_queries(:count => 1)
        expect { image.vim_performance_state_for_ts(timestamp) }.not_to make_database_queries
      end
    end

    # ci_mixin/rollup.rb uses this
    context "when using preload" do
      it "finds cached value" do
        vps_now
        vps
        rec_states = VimPerformanceState.where(:timestamp => [ts_now, timestamp])
        MiqPreloader.preload(image, :vim_performance_states, rec_states)
        expect(image).to receive(:perf_capture_state).never

        expect do
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps)
        end.not_to make_database_queries
      end

      it "falls back to cached now" do
        vps_now
        rec_states = VimPerformanceState.where(:timestamp => [ts_now, timestamp])
        MiqPreloader.preload(image, :vim_performance_states, rec_states)
        expect(image).to receive(:perf_capture_state).never

        expect do
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps_now)
        end.not_to make_database_queries
      end

      it "creates (and caches) a value when now isn't cached" do
        rec_states = VimPerformanceState.where(:timestamp => [ts_now, timestamp])
        MiqPreloader.preload(image, :vim_performance_states, rec_states)
        expect(image).to receive(:perf_capture_state).twice.and_return(vps_now) # fix

        expect do
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps_now)
        end.not_to make_database_queries
        expect { image.vim_performance_state_for_ts(timestamp) }.not_to make_database_queries
      end
    end
  end

  private

  def create_vps(image, timestamp, containers = [], nodes = [])
    FactoryBot.create(
      :vim_performance_state,
      :resource   => image,
      :timestamp  => timestamp,
      :state_data => {
        :assoc_ids => {
          :containers      => {:on => containers.map(&:id), :off => []},
          :container_nodes => {:on => nodes.map(&:id), :off => []},
        }
      }
    )
  end
end
