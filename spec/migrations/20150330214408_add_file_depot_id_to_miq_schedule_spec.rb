require "spec_helper"
require Rails.root.join("db/migrate/20150330214408_add_file_depot_id_to_miq_schedule")

describe AddFileDepotIdToMiqSchedule do
  let(:depot_stub)    { migration_stub(:FileDepot) }
  let(:schedule_stub) { migration_stub(:MiqSchedule) }

  migration_context :up do
    it "up" do
      schedule = schedule_stub.create!
      depot    = depot_stub.create!(:resource_type => "MiqSchedule", :resource_id => schedule.id)

      migrate

      expect(schedule.reload.file_depot_id).to eq(depot.id)
    end
  end

  migration_context :down do
    it "down" do
      depot    = depot_stub.create!
      schedule = schedule_stub.create!(:file_depot_id => depot.id)

      migrate

      expect(depot.reload.resource_id).to   eq(schedule.id)
      expect(depot.reload.resource_type).to eq("MiqSchedule")
    end
  end
end
