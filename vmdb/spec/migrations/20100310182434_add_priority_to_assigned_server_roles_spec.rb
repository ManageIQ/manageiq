require "spec_helper"
require Rails.root.join("db/migrate/20100310182434_add_priority_to_assigned_server_roles.rb")

describe AddPriorityToAssignedServerRoles do
  migration_context :up do
    let(:assigned_server_role_stub)  { migration_stub(:AssignedServerRole) }

    context "when the reserved field is empty" do
      it "sets the priority to 2" do
        asr = assigned_server_role_stub.create!(:reserved => nil)

        migrate

        asr.reload.priority.should == 2
      end
    end

    context "when the reserved field is not a hash object" do
      it "sets the priority to 2" do
        asr = assigned_server_role_stub.create!(:reserved => "not a hash")

        migrate

        asr.reload.priority.should == 2
      end
    end

    context "when the reserved field is a hash object" do
      context "and contains only the priority" do
        it "sets the priority and sets the reserved field to nil" do
          asr = assigned_server_role_stub.create!(:reserved => {:priority => 5})

          migrate

          asr.reload
          asr.priority.should == 5
          asr.reserved.should be_nil
        end
      end

      context "and contains priority among other data" do
        it "sets the priority and maintains the remaining reserved hash" do
          asr = assigned_server_role_stub.create!(:reserved => {:priority => 5, :another_key => "some value"})

          migrate

          asr.reload
          asr.priority.should == 5
          asr.reserved.should == {:another_key => "some value"}
        end
      end
    end
  end

  migration_context :down do
    let(:assigned_server_role_stub)  { migration_stub(:AssignedServerRole) }

    context "when reserved hash is empty" do
      it "sets the reserved hash priority" do
        asr = assigned_server_role_stub.create!(:priority => 9)

        migrate

        asr.reload.reserved.should == {:priority => 9}
      end
    end

    context "when reserved hash is not empty" do
      it "adds priority to the reserved hash" do
        asr = assigned_server_role_stub.create!(:priority => 9, :reserved => {:another_key => "some value"})

        migrate

        asr.reload.reserved.should == {:priority => 9, :another_key => "some value"}
      end
    end
  end
end
