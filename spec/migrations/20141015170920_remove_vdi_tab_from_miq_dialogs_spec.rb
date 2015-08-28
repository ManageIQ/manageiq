require "spec_helper"
require_migration

describe RemoveVdiTabFromMiqDialogs do
  let(:miq_dialog_stub) { migration_stub(:MiqDialog) }

  migration_context :up do
    it "Remove VDI tab from Provision dialogs" do
      d1 = miq_dialog_stub.create!(
        :name        => 'test',
        :dialog_type => 'MiqProvisionWorkflow',
        :content     => {
          :dialogs      => {
            :requester => {},
            :vdi       => {}
          },
          :dialog_order => [:requester, :vdi]
        }
      )

      migrate

      d1.reload
      expect(d1.content[:dialogs].keys).to eq([:requester])
      expect(d1.content[:dialog_order]).to eq([:requester])
    end
  end
end
