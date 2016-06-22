require_migration

describe AddDraftToOrchestrationTemplates do
  let(:orchestration_template_stub) { migration_stub(:OrchestrationTemplate) }

  migration_context :up do
    it "sets false to draft column" do
      orchestration_template = orchestration_template_stub.create!

      migrate

      expect(orchestration_template.reload.draft).to be_falsey
    end
  end
end
