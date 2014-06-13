require "spec_helper"
require Rails.root.join("db/migrate/20111227190505_convert_rubyrep_data_for_vim_performances_to_metrics_subtables_on_postgres.rb")

describe ConvertRubyrepDataForVimPerformancesToMetricsSubtablesOnPostgres do
  migration_context :up do
    let(:pending_change_stub) { migration_stub(:RrPendingChange) }
    let(:performance_stub)    { migration_stub(:VimPerformance) }

    context "converts vim_performances to metric subtables in rr#_pending_changes tables" do
      before do
        pending_change_stub.create_table
      end

      it "without remote settings configured" do
        if pending_change_stub.connection.adapter_name == "PostgreSQL"
          perf    = performance_stub.create!(:timestamp => Time.utc(2013, 1, 25, 0, 0, 0))
          changed = pending_change_stub.create!(:change_table => "vim_performances", :change_key => "something|#{perf.id}")
          deleted = pending_change_stub.create!(:change_table => "vim_performances", :change_key => "something|#{perf.id + 1}")
          ignored = pending_change_stub.create!(:change_table => "some_other_table")

          migrate

          lambda { deleted.reload }.should raise_error(ActiveRecord::RecordNotFound)
          changed.reload.change_table.should == "metric_rollups_01"
          ignored.reload.change_table.should == "some_other_table"
        end
      end
    end
  end
end
