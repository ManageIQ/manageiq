require "spec_helper"
require Rails.root.join("db/migrate/20120511235150_remove_reserves_values_for_miq_worker_sql_spid.rb")

describe RemoveReservesValuesForMiqWorkerSqlSpid do
  migration_context :up do
    let(:reserve_stub) { migration_stub(:Reserve) }

    it "removes reserves values for MiqWorker#sql_spid" do
      expected_destroyed = reserve_stub.create!(:resource_type => "MiqWorker", :reserved => {:sql_spid => 123})
      expected_cleaned   = reserve_stub.create!(:resource_type => "MiqWorker", :reserved => {:sql_spid => 123, :other => "value"})
      expected_skipped   = reserve_stub.create!(:resource_type => "SomeClass", :reserved => {:sql_spid => 123})

      migrate

      reserve_stub.count.should == 2
      lambda { expected_destroyed.reload }.should raise_error(ActiveRecord::RecordNotFound)
      expected_cleaned.reload.reserved.should == {:other => "value"}
      expected_skipped.reload.reserved.should == {:sql_spid => 123}
    end
  end
end
