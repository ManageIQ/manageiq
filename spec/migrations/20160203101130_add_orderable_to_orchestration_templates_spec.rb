require_migration

describe AddOrderableToOrchestrationTemplates do
  let(:orchestration_template_stub) { migration_stub(:OrchestrationTemplate) }

  migration_context :up do
    it "sets true to column orderable" do
      orchestration_template = orchestration_template_stub.create!

      migrate

      expect(orchestration_template.reload.orderable).to be_truthy
    end
  end
end
