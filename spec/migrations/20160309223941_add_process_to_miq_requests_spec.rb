require_migration

describe AddProcessToMiqRequests do
  migration_context :up do
    let(:miq_request_stub) { migration_stub(:MiqRequest) }

    it "updates existing records" do
      miq_request = miq_request_stub.create!

      migrate

      expect(miq_request.reload.process).to be true
    end
  end
end
