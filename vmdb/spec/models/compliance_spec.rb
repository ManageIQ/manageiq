require "spec_helper"

describe Compliance do
  context "A small virtual infrastructure" do
    before(:each) do
      @zone  = FactoryGirl.create(:zone)
      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)
      @server = FactoryGirl.create(:miq_server, :zone => @zone, :guid => @guid)
      MiqServer.my_server_clear_cache
      @ems   = FactoryGirl.create(:ems_vmware,    :name => "Test EMS", :zone => @zone)
      @host1 = FactoryGirl.create(:host,      :name => "Host1", :ext_management_system => @ems)
      @host2 = FactoryGirl.create(:host,      :name => "Host2")
      @vm1   = FactoryGirl.create(:vm_vmware, :name => "VM1", :host => @host1, :ext_management_system => @ems)
    end

    it "should queue single vm for compliance" do
      Compliance.check_compliance_queue(@vm1)

      MiqQueue.count.should == 1
      msg = MiqQueue.first
      validate_compliance_message(msg, @vm1)
    end

    it "should queue single vm for compliance via vm method" do
      @vm1.check_compliance_queue

      MiqQueue.count.should == 1
      msg = MiqQueue.first
      validate_compliance_message(msg, @vm1)
    end

    it "should queue single host for compliance" do
      Compliance.check_compliance_queue(@host1)

      MiqQueue.count.should == 1
      msg = MiqQueue.first
      validate_compliance_message(msg, @host1)
    end

    it "should queue single host for compliance via host method" do
      @host1.check_compliance_queue

      MiqQueue.count.should == 1
      msg = MiqQueue.first
      validate_compliance_message(msg, @host1)
    end

    it "should queue multiple objects for compliance" do
      Compliance.check_compliance_queue([@vm1, @host1])

      MiqQueue.count.should == 2
      MiqQueue.all.each do |qitem|
        klass, id = qitem.args.first
        target = klass.constantize.find(id)
        case target
        when Vm;   target.should == @vm1
        when Host; target.should == @host1
        end
        validate_compliance_message(qitem, target)
      end
    end

    it "should queue multiple objects for compliance with inputs" do
      inputs = { :foo => 'bar' }
      Compliance.check_compliance_queue([@vm1, @host1], inputs)

      MiqQueue.count.should == 2
      MiqQueue.all.each do |qitem|
        klass, id = qitem.args.first
        target = klass.constantize.find(id)
        case target
        when Vm;   target.should == @vm1
        when Host; target.should == @host1
        end
        validate_compliance_message(qitem, target, inputs)
      end
    end

    it "should queue single host for scan_and_check_compliance via host method" do
      @host1.scan_and_check_compliance_queue

      MiqQueue.count.should == 1
      msg = MiqQueue.first
      validate_scan_and_check_compliance_message(msg, @host1)
    end

    it "should queue multiple objects for scan_and_check_compliance" do
      Compliance.scan_and_check_compliance_queue([@vm1, @host1, @host2])

      MiqQueue.count.should == 2
      MiqQueue.all.each do |qitem|
        klass, id = qitem.args.first
        target = klass.constantize.find(id)
        case id
        when @host1.id; target.should == @host1
        when @host2.id; target.should == @host2
        end
        validate_scan_and_check_compliance_message(qitem, target)
      end
    end

    it "should queue multiple objects for scan_and_check_compliance with inputs" do
      inputs = { :foo => 'bar' }
      Compliance.scan_and_check_compliance_queue([@vm1, @host1, @host2], inputs)

      MiqQueue.count.should == 2
      MiqQueue.all.each do |qitem|
        klass, id = qitem.args.first
        target = klass.constantize.find(id)
        case id
        when @host1.id; target.should == @host1
        when @host2.id; target.should == @host2
        end
        validate_scan_and_check_compliance_message(qitem, target, inputs)
      end
    end

    context ".scan_and_check_compliance" do
      it "should raise event request_host_scan" do
        MiqEvent.should_receive(:raise_evm_event).with(@host1, "request_host_scan", {})
        Compliance.scan_and_check_compliance([@host1.class.name, @host1.id])
      end
    end
  end

  private

  def validate_compliance_message(msg, obj, inputs = {})
    msg.method_name.should == "check_compliance"
    msg.class_name.should  == "Compliance"
    msg_obj = msg.args.first
    msg_obj.first.should   == obj.class.name
    msg_obj.last.should    == obj.id
    msg_inputs = msg.args.last
    msg_inputs.should      == inputs
  end

  def validate_scan_and_check_compliance_message(msg, obj, inputs = {})
    msg.method_name.should == "scan_and_check_compliance"
    msg.class_name.should  == "Compliance"
    msg.task_id.should     == 'vc-refresher'
    msg.role.should        == 'ems_inventory'
    zone = obj.ext_management_system ? obj.ext_management_system.my_zone : nil
    msg.zone.should        == zone
    msg_obj = msg.args.first
    msg_obj.first.should   == obj.class.name
    msg_obj.last.should    == obj.id
    msg_inputs = msg.args.last
    msg_inputs.should      == inputs
  end

end
