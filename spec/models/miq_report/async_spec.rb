RSpec.describe MiqReport do
  context "Generator::Async" do
    context ".async_generate_tables" do
      let(:report) do
        MiqReport.new(
          :name      => "Custom VM report",
          :title     => "Custom VM report",
          :rpt_group => "Custom",
          :rpt_type  => "Custom",
          :db        => "ManageIQ::Providers::InfraManager::Vm",
        )
      end

      it "creates task, queue, audit event" do
        User.seed
        EvmSpecHelper.local_miq_server
        ServerRole.seed
        expect(AuditEvent).to receive(:success)

        described_class.async_generate_tables(:reports => [report])
        task = MiqTask.first
        expect(task.name).to eq("Generate Reports: [\"#{report.name}\"]")

        message = MiqQueue.find_by(:method_name => "_async_generate_tables")
        expect(message).to have_attributes(
          :role        => "reporting",
          :zone        => nil,
          :class_name  => report.class.name,
          :method_name => "_async_generate_tables"
        )

        expect(message.args.first).to eq(task.id)
      end
    end

    context "._async_generate_tables" do
      it "unknown taskid" do
        expect { MiqReport._async_generate_tables(111111, :reports => []) }.to raise_error(MiqException::Error)
      end

      it "known taskid" do
        task = MiqTask.create
        expect { MiqReport._async_generate_tables(task.id, :reports => []) }.not_to raise_error
      end
    end
  end
end
