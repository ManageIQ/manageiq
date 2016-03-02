require 'rails_helper'

describe UserGroup do
  describe "::seed" do
    subject { described_class.first }
    let!(:miq_user_role) { FactoryGirl.create(:miq_user_role, name: "EvmRole-super_administrator") }
    let(:role_map) { { "EvmGroup-super_administrator" => "super_administrator" } }

    before do
      allow(described_class).to receive(:seeded_role_map).and_return(role_map)
      allow(described_class).to receive(:seeded_filter_map).and_return({})
      UserGroup.seed
    end

    it "creates UserGroup with Entitlement by MiqUserRole" do
      expect(UserGroup.count).to eq 1
      expect(MiqGroup.count).to eq 1

      expect(subject.description).to eq("EvmGroup-super_administrator")
      expect(subject.miq_group).to be_present
      expect(subject.miq_group.miq_user_role).to be_present
      expect(subject.miq_group.miq_user_role.name).to eq miq_user_role.name
    end

    it "is idempotent" do
      UserGroup.seed # Seed a second time

      expect(UserGroup.count).to eq 1
      expect(MiqUserRole.count).to eq 1
      expect(MiqGroup.count).to eq 1

      expect(subject.description).to eq("EvmGroup-super_administrator")
      expect(subject.miq_group).to be_present
      expect(subject.miq_group.miq_user_role).to be_present
      expect(subject.miq_group.miq_user_role.name).to eq miq_user_role.name
    end
  end
end
