require "spec_helper"

describe ExtManagementSystem do
  it ".model_name_from_emstype" do
    described_class.leaf_subclasses.each do |klass|
      described_class.model_name_from_emstype(klass.ems_type).should == klass.name
    end
    described_class.model_name_from_emstype('foo').should be_nil
  end

  let(:all_types) do
    %w(
      ec2
      foreman_configuration
      foreman_provisioning
      kubernetes
      openstack
      openstack_infra
      rhevm
      scvmm
      vmwarews
    )
  end

  it ".types" do
    described_class.types.should match_array(all_types)
  end

  it ".supported_types" do
    described_class.supported_types.should match_array(all_types)
  end

  it ".ems_discovery_types" do
    expected_types = [
      "scvmm",
      "rhevm",
      "virtualcenter"
    ]

    expect(described_class.ems_discovery_types).to match_array(expected_types)
  end

  context "with two small envs" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      @zone2 = FactoryGirl.create(:small_environment)
    end

    it "refresh_all_ems_timer will refresh for all emses in zone1" do
      @ems1 = @zone1.ext_management_systems.first
      MiqServer.stub(:my_server).and_return(@zone1.miq_servers.first)
      described_class.should_receive(:refresh_ems).with([@ems1.id], true)
      described_class.refresh_all_ems_timer
    end

    it "refresh_all_ems_timer will refresh for all emses in zone2" do
      @ems2 = @zone2.ext_management_systems.first
      MiqServer.stub(:my_server).and_return(@zone2.miq_servers.first)
      described_class.should_receive(:refresh_ems).with([@ems2.id], true)
      described_class.refresh_all_ems_timer
    end
  end

  context "with virtual columns" do
    before(:each) do
      @ems = FactoryGirl.create(:ems_vmware)
      (1..5).each { |i| FactoryGirl.create(:vm_vmware, :ext_management_system => @ems, :name => "vm_#{i}") }
    end

    it "#total_vms_on" do
      @ems.total_vms_on.should == 5
    end

    it "#total_vms_off" do
      @ems.total_vms_off.should == 0

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "poweredOff") }
      @ems.total_vms_off.should == 5
    end

    it "#total_vms_unknown" do
      @ems.total_vms_unknown.should == 0

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "unknown") }
      @ems.total_vms_unknown.should == 5
    end

    it "#total_vms_never" do
      @ems.total_vms_never.should == 0

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "never") }
      @ems.total_vms_never.should == 5
    end

    it "#total_vms_suspended" do
      @ems.total_vms_suspended.should == 0

      @ems.vms.each { |v| v.update_attributes(:raw_power_state => "suspended") }
      @ems.total_vms_suspended.should == 5
    end

    %w(total_vms_on total_vms_off total_vms_unknown total_vms_never total_vms_suspended).each do |vcol|
      it "should have virtual column #{vcol} " do
        described_class.should have_virtual_column "#{vcol}", :integer
      end
    end
  end

  context "validates" do
    described_class.leaf_subclasses.collect{|ems| ems.name.underscore.to_sym}.each do |t|
      next if t == :ems_amazon # Amazon is tested in ems_amazon_spec.rb

      context "for #{t}" do

        it "name" do
          expect { FactoryGirl.create(t, :name => "ems_1", :ipaddress => "1.1.1.1", :hostname => "ems_1") }.to_not raise_error
          expect { FactoryGirl.create(t, :name => "ems_1", :ipaddress => "2.2.2.2", :hostname => "ems_2") }.to     raise_error
        end

        context "ipaddress" do
          it "duplicate ipaddress" do
            expect { FactoryGirl.create(t, :ipaddress => "1.1.1.1", :hostname => "ems_1") }.to_not raise_error
            expect { FactoryGirl.create(t, :ipaddress => "1.1.1.1", :hostname => "ems_2") }.to     raise_error
          end

          it "blank ipaddress" do
            expect { FactoryGirl.create(t, :ipaddress => "", :hostname => "ems_1") }.to raise_error
          end

          it "nil ipaddress" do
            expect { FactoryGirl.create(t, :ipaddress => nil, :hostname => "ems_1") }.to raise_error
          end
        end

        context "hostname" do
          it "duplicate hostname" do
            expect { FactoryGirl.create(t, :ipaddress => "1.1.1.1", :hostname => "ems_1") }.to_not raise_error
            expect { FactoryGirl.create(t, :ipaddress => "2.2.2.2", :hostname => "ems_1") }.to     raise_error
            expect { FactoryGirl.create(t, :ipaddress => "3.3.3.3", :hostname => "EMS_1") }.to     raise_error
          end

          it "blank hostname" do
            expect { FactoryGirl.create(t, :ipaddress => "1.1.1.1", :hostname => "") }.to raise_error
          end

          it "nil hostname" do
            expect { FactoryGirl.create(t, :ipaddress => "1.1.1.1", :hostname => nil) }.to raise_error
          end
        end

      end
    end

    context "across sub-classes" do
      before do
        @same_host_name      = "us-east-1"
        @different_host_name = "us-west-1"
        @ems = FactoryGirl.create(:ems_vmware, :hostname => @same_host_name)
      end

      it "duplicate name" do
        described_class.leaf_subclasses.collect{|ems| ems.name.underscore.to_sym}.each do |t|
          expect { FactoryGirl.create(t, :name => @ems.name, :hostname => @different_host_name) }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Name has already been taken")
        end
      end

      it "duplicate ipaddress" do
        described_class.leaf_subclasses.collect{|ems| ems.name.underscore.to_sym}.each do |t|
          provider = FactoryGirl.build(t, :ipaddress => @ems.ipaddress, :hostname => @different_host_name)

          if provider.hostname_ipaddress_required?
            expect { provider.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: IP Address has already been taken")
          else
            expect { provider.save! }.to_not raise_error
            provider.destroy
          end
        end
      end

      it "duplicate hostname" do
        described_class.leaf_subclasses.collect{|ems| ems.name.underscore.to_sym}.each do |t|
          provider = FactoryGirl.build(t, :hostname => @same_host_name)

          if provider.hostname_ipaddress_required?
            expect { provider.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Host Name has already been taken")
          else
            expect { provider.save! }.to_not raise_error
          end
        end
      end
    end
  end

end
