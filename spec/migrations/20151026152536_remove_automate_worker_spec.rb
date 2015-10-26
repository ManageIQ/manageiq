require "spec_helper"
require_migration

describe RemoveAutomateWorker do
  let(:miq_worker_stub) { migration_stub(:MiqWorker) }

  migration_context :up do
    it "up" do
      miq_worker_stub.create!(:type => 'MiqAutomateWorker')

      migrate

      expect(MiqWorker.select(:type => 'MiqAutomateWorker')).to be_empty
    end
  end
end
