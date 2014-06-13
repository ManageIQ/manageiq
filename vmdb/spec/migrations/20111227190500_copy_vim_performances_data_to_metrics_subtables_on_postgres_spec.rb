require "spec_helper"
require Rails.root.join("db/migrate/20111227190500_copy_vim_performances_data_to_metrics_subtables_on_postgres.rb")

describe CopyVimPerformancesDataToMetricsSubtablesOnPostgres do
  migration_context :up do
    let(:performance_stub)    { migration_stub(:VimPerformance) }

    context "copies vim_performances to metric subtables" do
      it "migrate succeeds without error" do
        if performance_stub.connection.adapter_name == "PostgreSQL"
          perf    = performance_stub.create!(:timestamp => Time.utc(2013, 1, 25, 0, 0, 0),
                                             :capture_interval_name => 'realtime')

          performance_stub.count.should == 1

          # migrate will fail if pg_hba.conf requires password for localhost connections
          # and the password/etc. setup isn't configured properly
          migrate
        end
      end
    end
  end
end
