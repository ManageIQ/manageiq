require "spec_helper"
require Rails.root.join("db/migrate/20110203035917_make_polymorphic_handler_in_miq_queue.rb")

describe MakePolymorphicHandlerInMiqQueue do
  migration_context :up do
    let(:queue_stub) { migration_stub(:MiqQueue) }

    it "updates MiqCimInstance type" do
      queue_with_handler = queue_stub.create!(:miq_worker_id => 2)
      queue_no_handler   = queue_stub.create!(:miq_worker_id => nil)

      migrate

      queue_with_handler.reload.handler_type.should == "MiqWorker"
      queue_no_handler.reload.handler_type.should be_nil
    end
  end

  migration_context :down do
    let(:queue_stub) { migration_stub(:MiqQueue) }

    it "updates MiqCimInstance type" do
      queue_with_handler = queue_stub.create!(:handler_type => "MiqWorker",
                                              :handler_id   => 2)
      queue_no_handler   = queue_stub.create!(:handler_type => nil,
                                              :handler_id   => 2)

      migrate

      queue_with_handler.reload.miq_worker_id.should == 2
      queue_no_handler.reload.miq_worker_id.should be_nil
    end
  end
end
