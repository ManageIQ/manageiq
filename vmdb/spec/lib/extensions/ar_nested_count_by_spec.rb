require "spec_helper"

describe "AR Nested Count By extension" do
  context "miq_queue with messages" do
    before(:each) do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone

      FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_DEQUEUE,  :role => "role2", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_READY,    :role => "role1", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_READY,    :role => "role1", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_READY,    :role => "role1", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => "east",     :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => "west",     :state => MiqQueue::STATE_READY,    :role => "role3", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_ERROR,    :role => "role1", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_WARN,     :role => "role3", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => "east",     :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20)
      FactoryGirl.create(:miq_queue, :zone => "west",     :state => MiqQueue::STATE_ERROR,    :role => "role2", :priority => 20)
    end

    it "should count by state, zone and role" do
      expect(MiqQueue.nested_count_by(%w(state zone role))).to eq(
        MiqQueue::STATE_READY => {
          "default" => { "role1" => 3 },
          "west"    => { "role3" => 1 },
        },
        MiqQueue::STATE_DEQUEUE => {
          "default" => { "role1" => 2, "role2" => 1 },
          "east"    => { "role1" => 2 },
        },
        MiqQueue::STATE_WARN => {
          "default" => { "role3" => 1 },
        },
        MiqQueue::STATE_ERROR => {
          "default" => { "role1" => 1 },
          "west"    => { "role2" => 1 },
        }
      )
    end

    it "should respect nested where, and support individual args (vs an array)" do
      expect(MiqQueue.where(:zone => "west").nested_count_by("role", "state")).to eq(
        "role3" => { MiqQueue::STATE_READY => 1 },
        "role2" => { MiqQueue::STATE_ERROR => 1 },
      )
    end

    it "should count by role and state" do
      expect(MiqQueue.nested_count_by(%w(role state))).to eq(
        "role1" => { "dequeue" => 4, "ready" => 3, "error" => 1 },
        "role2" => { "dequeue" => 1, "error" => 1 },
        "role3" => { "ready"   => 1, "warn"  => 1 },
      )
    end
  end
end
