require 'ansible_tower_client'
require 'faraday'
describe ManageIQ::Providers::AnsibleTower::AutomationManager::Job do
  let(:faraday_connection) { instance_double("Faraday::Connection", :post => post, :get => get) }
  let(:post) { instance_double("Faraday::Result", :body => {}.to_json) }
  let(:get)  { instance_double("Faraday::Result", :body => {'id' => 1}.to_json) }

  let(:connection) { double(:connection, :api => double(:api, :jobs => double(:jobs, :find => the_raw_job))) }

  let(:manager)  { FactoryGirl.create(:automation_manager_ansible_tower, :provider) }
  let(:mock_api) { AnsibleTowerClient::Api.new(faraday_connection) }
  let(:the_raw_job) do
    AnsibleTowerClient::Job.new(
      mock_api,
      'id'         => '1',
      'name'       => template.name,
      'status'     => 'Successful',
      'extra_vars' => {'param1' => 'val1'}.to_json
    ).tap { |rjob| allow(rjob).to receive(:stdout).and_return('job stdout') }
  end

  let(:template) { FactoryGirl.create(:configuration_script, :manager => manager) }
  subject { FactoryGirl.create(:ansible_tower_job, :job_template => template, :ext_management_system => manager) }

  describe 'job operations' do
    context ".create_job" do
      it 'creates a job' do
        expect(template).to receive(:run).and_return(the_raw_job)

        job = ManageIQ::Providers::AnsibleTower::AutomationManager::Job.create_job(template, {})
        expect(job.class).to                 eq(described_class)
        expect(job.name).to                  eq(template.name)
        expect(job.ems_ref).to               eq(the_raw_job.id)
        expect(job.job_template).to          eq(template)
        expect(job.status).to                eq(the_raw_job.status)
        expect(job.ext_management_system).to eq(manager)
      end

      it 'catches errors from provider' do
        expect(template).to receive(:run).and_raise('bad request')

        expect do
          ManageIQ::Providers::AnsibleTower::AutomationManager::Job.create_job(template, {})
        end.to raise_error(MiqException::MiqOrchestrationProvisionError)
      end
    end

    context "#refres_ems" do
      before do
        allow_any_instance_of(Provider).to receive_messages(:connect => connection)
      end

      it 'syncs the job with the provider' do
        subject.refresh_ems
        expect(subject.ems_ref).to eq(the_raw_job.id)
        expect(subject.status).to  eq(the_raw_job.status)
        expect(subject.parameters.first).to have_attributes(:name => 'param1', :value => 'val1')
      end

      it 'catches errors from provider' do
        expect(connection.api.jobs).to receive(:find).and_raise('bad request')
        expect { subject.refresh_ems }.to raise_error(MiqException::MiqOrchestrationUpdateError)
      end
    end
  end

  describe 'job status' do
    before do
      allow_any_instance_of(Provider).to receive_messages(:connect => connection)
    end

    context '#raw_status and #raw_exists' do
      it 'gets the stack status' do
        rstatus = subject.raw_status
        expect(rstatus).to have_attributes(:status => 'Successful', :reason => nil)

        expect(subject.raw_exists?).to be_truthy
      end

      it 'detects job not exist' do
        expect(connection.api.jobs).to receive(:find).twice.and_raise(Faraday::ResourceNotFound.new(nil))
        expect { subject.raw_status }.to raise_error(MiqException::MiqOrchestrationStackNotExistError)

        expect(subject.raw_exists?).to be_falsey
      end

      it 'catches errors from provider' do
        expect(connection.api.jobs).to receive(:find).twice.and_raise("bad happened")
        expect { subject.raw_status }.to raise_error(MiqException::MiqOrchestrationStatusError)

        expect { subject.raw_exists? }.to raise_error(MiqException::MiqOrchestrationStatusError)
      end
    end
  end

  describe '#raw_stdout' do
    before do
      allow_any_instance_of(Provider).to receive_messages(:connect => connection)
    end

    it 'gets the standard output of the job' do
      expect(subject.raw_stdout).to eq('job stdout')
    end

    it 'catches errors from provider' do
      expect(connection.api.jobs).to receive(:find).and_raise("bad happened")
      expect { subject.raw_stdout }.to raise_error(MiqException::MiqOrchestrationStatusError)
    end
  end
end
