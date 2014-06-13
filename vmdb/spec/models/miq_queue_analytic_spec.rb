require "spec_helper"

describe MiqQueueAnalytic do
  #this before is copied from MiqQueue
  context "miq_queue with messages" do
    before(:each) do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone

      @zone_e = FactoryGirl.create(:zone, :name => "east")
      @zone_w = FactoryGirl.create(:zone, :name => "west")

      @role1  = FactoryGirl.create(:server_role, :name => "role1")
      @role2  = FactoryGirl.create(:server_role, :name => "role2")
      @role3  = FactoryGirl.create(:server_role, :name => "role3")

      #@miq_server.update_attribute(:role => [@role1,@role2,@role3])

      @t1 = Time.parse("Wed Apr 20 00:15:00 UTC 2011")
      @t2 = Time.parse("Mon Apr 25 10:30:15 UTC 2011")
      @t3 = Time.parse("Thu Apr 28 20:45:30 UTC 2011")

      Timecop.freeze(Time.parse("Thu Apr 30 12:45:00 UTC 2011"))

      @msg = []
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20, :created_on => @t1)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20, :created_on => @t1)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_DEQUEUE,  :role => "role2", :priority => 20, :created_on => @t1)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_READY,    :role => "role1", :priority => 20, :created_on => @t1)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_READY,    :role => "role1", :priority => 20, :created_on => @t2)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_READY,    :role => "role1", :priority => 20, :created_on => @t3)
      @msg << FactoryGirl.create(:miq_queue, :zone => "east",     :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20, :created_on => @t3)
      @msg << FactoryGirl.create(:miq_queue, :zone => "west",     :state => MiqQueue::STATE_READY,    :role => "role3", :priority => 20, :created_on => @t3)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_ERROR,    :role => "role1", :priority => 20, :created_on => @t2)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_WARN,     :role => "role3", :priority => 20, :created_on => @t2)
      @msg << FactoryGirl.create(:miq_queue, :zone => "east",     :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20, :created_on => Time.now.utc)
      @msg << FactoryGirl.create(:miq_queue, :zone => "west",     :state => MiqQueue::STATE_ERROR,    :role => "role2", :priority => 20, :created_on => Time.now.utc)
    end

    after do
      Timecop.return
    end

    it "should generate a report" do
      report = MiqQueueAnalytic.build_results_for_report_analytics(
        #to be honest, this is 'other' and ignored.
        #didn't know how to get the MiqServer to return all roles
        # :resource_id => @miq_server.id,
        # :resource_type => "MiqServer"
        :resource_id => @role1.id,
        :resource_type => "ServerRole"
      ).first

      expect(report.detect{|x| x.role == "role1" }).to have_attributes(
        :age_of_next_in_queue => Time.now - @t3,
        :age_of_last_in_queue => Time.now - @t1,
        :messages_in_ready    => 3,
        :messages_in_process  => 4
      )
      expect(report.detect{|x| x.role == "role2" }).to have_attributes(
        :age_of_next_in_queue => 0,
        :age_of_last_in_queue => 0,
        :messages_in_ready    => 0,
        :messages_in_process  => 1
      )
      expect(report.detect{|x| x.role == "role3" }).to have_attributes(
        :age_of_next_in_queue => Time.now - @t3,
        :age_of_last_in_queue => Time.now - @t3,
        :messages_in_ready    => 1,
        :messages_in_process  => 0
      )
      expect(report.detect{|x| x.role == "No specified role" }).to have_attributes(
        :age_of_next_in_queue => 0,
        :age_of_last_in_queue => 0,
        :messages_in_ready    => 0,
        :messages_in_process  => 0
      )
      expect(report.size).to eq(4)
    end
  end
end
