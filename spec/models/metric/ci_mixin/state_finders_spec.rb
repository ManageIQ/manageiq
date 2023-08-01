RSpec.describe Metric::CiMixin::StateFinders do
  let(:image) { FactoryBot.create(:container_image) }
  let(:container1) { FactoryBot.create(:container, :container_image => image) }
  let(:container2) { FactoryBot.create(:container, :container_image => image) }

  # region is currently the only class that has multiple rollups
  let(:region) { MiqRegion.my_region || MiqRegion.seed }
  let(:ems1) { FactoryBot.create(:ext_management_system) } # implied :region => region
  let(:ems2) { FactoryBot.create(:ext_management_system) }
  let(:storage1) { FactoryBot.create(:storage) }
  let(:storage2) { FactoryBot.create(:storage) }

  let(:ts_now) { Time.now.utc.beginning_of_hour }
  let(:timestamp) { 2.hours.ago.utc.beginning_of_hour }

  describe "#vim_performance_state_association" do
    let(:c_vps_now) { create_vps(image, ts_now, :containers => [container1, container2]) }
    let(:c_vps) { create_vps(image, timestamp, :containers => [container1]) }

    let(:r_vps_now) { create_vps(region, ts_now, :ext_management_systems => [ems1, ems2], :storages => [storage1, storage2]) }
    let(:r_vps) { create_vps(region, timestamp, :ext_management_systems => [ems1], :storages => [storage1]) }

    it "performs a single query when looking up an association multiple times" do
      c_vps

      expect do
        expect(image.vim_performance_state_association(timestamp, :containers)).to eq([container1])
      end.to make_database_queries(:count => 2)

      expect do
        expect(image.vim_performance_state_association(timestamp, :containers)).to eq([container1])
      end.to make_database_queries(:count => 0)
    end

    it "supports virtual associations" do
      r_vps

      expect do
        expect(region.vim_performance_state_association(timestamp, :ext_management_systems)).to eq([ems1])
      end.to make_database_queries(:count => 2)

      expect do
        expect(region.vim_performance_state_association(timestamp, :ext_management_systems)).to eq([ems1])
      end.to make_database_queries(:count => 1)
    end

    it "fetches a second timestamp" do
      c_vps
      c_vps_now
      expect(image.vim_performance_state_association(timestamp, :containers)).to match_array([container1])

      expect do
        expect(image.vim_performance_state_association(ts_now, :containers)).to match_array([container1, container2])
      end.to make_database_queries(:count => 2)
    end

    it "assigns reverse association" do
      c_vps
      expect(image.vim_performance_state_association(timestamp, :containers)).to match_array([container1])

      expect do
        c = image.vim_performance_state_association(timestamp, :containers).first
        expect(c.container_image).to eq(image)
      end.to make_database_queries(:count => 0)
    end
  end

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

      it "doesn't search db for now since perf_capture_state will do that" do
        expect(image).to receive(:perf_capture_state).once.and_return(vps_now)

        expect do
          expect(image.vim_performance_state_for_ts(ts_now)).to eq(vps_now)
        end.to make_database_queries(:count => 0)
        expect { image.vim_performance_state_for_ts(ts_now) }.not_to make_database_queries
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
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps)
        end.not_to make_database_queries
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
        expect(image).to receive(:perf_capture_state).once.and_return(vps_now)

        expect do
          expect(image.vim_performance_state_for_ts(timestamp)).to eq(vps_now)
        end.not_to make_database_queries
        expect { image.vim_performance_state_for_ts(timestamp) }.not_to make_database_queries
      end
    end
  end

  private

  def create_vps(parent, timestamp, association = {})
    FactoryBot.create(
      :vim_performance_state,
      :resource   => parent,
      :timestamp  => timestamp,
      :state_data => {
        :assoc_ids => association.transform_values do |values|
          {:on => values.map(&:id), :off => []}
        end
      }
    )
  end
end
