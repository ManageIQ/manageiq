require "spec_helper"
require Rails.root.join("db/migrate/20120328210051_add_expires_on_to_miq_queue.rb")

describe AddExpiresOnToMiqQueue do
  migration_context :up do
    let(:reserve_stub) { migration_stub(:Reserve) }
    let(:miq_queue_stub) { migration_stub(:MiqQueue) }

    it "adds expires_on to miq_queue" do
      expire_time = Time.zone.now
      queue1 = miq_queue_stub.create!
      reserve1 = reserve_stub.create!(:resource_id => queue1.id, :resource_type => "MiqQueue", :reserved => {:expires_on => expire_time})
      queue2 = miq_queue_stub.create!
      reserve2 = reserve_stub.create!(:resource_id => queue2.id, :resource_type => "MiqQueue", :reserved => {:expires_on => expire_time, :something_else => 2})
      queue3 = miq_queue_stub.create!

      migrate

      lambda { reserve1.reload }.should raise_error(ActiveRecord::RecordNotFound)
      reserve2.reload.reserved.should == {:something_else => 2}
      queue1.reload.expires_on.to_s.should == expire_time.to_s
      queue2.reload.expires_on.to_s.should == expire_time.to_s
      queue3.reload.expires_on.should be_nil
    end
  end
end
