require "spec_helper"
require Rails.root.join('db/migrate/20100408131912_update_system_schedules.rb')

describe UpdateSystemSchedules do
  migration_context :up do
    let(:schedule_stub) { migration_stub(:MiqSchedule) }

    it "should upgrade MiqReports to system prod_default" do
      schedule1 = schedule_stub.create!(:towhat => 'MiqReport', :prod_default => 'not_system')

      migrate

      schedule1.reload.prod_default.should == 'system'
    end

    it "should not modify other classes" do
      schedule2 = schedule_stub.create!(:towhat => "Foo", :prod_default => 'not_system')

      migrate

      schedule2.reload.prod_default.should == 'not_system'
    end
  end
end
