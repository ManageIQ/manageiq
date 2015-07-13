require "spec_helper"

describe MiqProvisionRedhat do
  context "::Placement" do
    before do
      ems      = FactoryGirl.create(:ems_redhat_with_authentication)
      template = FactoryGirl.create(:template_redhat, :ext_management_system => ems)
      vm       = FactoryGirl.create(:vm_redhat)
      @cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => ems)
      options  = {:src_vm_id => template.id}

      @task = FactoryGirl.create(:miq_provision_redhat, :source      => template,
                                                        :destination => vm,
                                                        :state       => 'pending',
                                                        :status      => 'Ok',
                                                        :options     => options)
    end

    it "#manual_placement raise error" do
      @task.options[:placement_auto] = false
      expect { @task.send(:placement) }.to raise_error(MiqException::MiqProvisionError)
    end

    it "#manual_placement" do
      @task.options[:placement_cluster_name] = @cluster.id
      @task.options[:placement_auto]         = false
      check
    end

    it "#automatic_placement" do
      @task.should_receive(:get_placement_via_automate).and_return(:cluster => @cluster)
      @task.options[:placement_auto]         = true
      check
    end

    it "automate returns nothing" do
      @task.options[:placement_cluster_name] = @cluster.id
      @task.should_receive(:get_placement_via_automate).and_return({})
      @task.options[:placement_auto]         = true
      check
    end

    def check
      @task.send(:placement)
      @task.options[:dest_cluster].should eql([@cluster.id, @cluster.name])
    end
  end
end
