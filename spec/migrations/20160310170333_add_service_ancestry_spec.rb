require "spec_helper"
require_migration

describe AddServiceAncestry do
  let(:service_stub) { migration_stub(:Service) }

  migration_context :up do
    # nodes:
    # s1
    #   s11
    #     s111
    #     s112
    # s2
    #   s21 (created before parent)
    it "updates tree" do
      s21  = service_stub.create!
      s1   = service_stub.create!
      s2   = service_stub.create!
      s11  = service_stub.create!(:service_id => s1.id)
      s111 = service_stub.create!(:service_id => s11.id)
      s112 = service_stub.create!(:service_id => s11.id)
      s21.update_attributes(:service_id => s2.id) # note: s21.id < s2.id

      migrate

      expect(s1.reload.ancestry).to be_nil
      expect(s2.reload.ancestry).to be_nil

      expect(s11.reload.ancestry).to eq(s1.id.to_s)
      expect(s111.reload.ancestry).to eq("#{s1.id}/#{s11.id}")
      expect(s112.reload.ancestry).to eq("#{s1.id}/#{s11.id}")
      expect(s21.reload.ancestry).to eq(s2.id.to_s)
    end
  end

  migration_context :down do
    it "updates tree" do
      s21  = service_stub.create!
      s1   = service_stub.create!
      s2   = service_stub.create!
      s11  = service_stub.create!(:ancestry => s1.id.to_s)
      s111 = service_stub.create!(:ancestry => "#{s1.id}/#{s11.id}")
      s112 = service_stub.create!(:ancestry => "#{s1.id}/#{s11.id}")
      s21.update_attributes(:ancestry => s2.id.to_s) # note: s21.id < s2.id

      migrate

      expect(s1.reload.service_id).to eq(nil)
      expect(s2.reload.service_id).to eq(nil)

      expect(s11.reload.service_id).to eq(s1.id)
      expect(s111.reload.service_id).to eq(s11.id)
      expect(s112.reload.service_id).to eq(s11.id)
      expect(s21.reload.service_id).to eq(s2.id)
    end
  end
end
