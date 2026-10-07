RSpec.describe MiqProvision::Ownership do
  # These tests cover the full matrix of owning-group resolution when a VM is
  # provisioned.  The goal: vm.miq_group should always reflect the group that
  # was active when the request was created, NOT the user's live current_group
  # in the database at provision time.
  #
  # Root cause: set_ownership uses user.current_group (DB value), so if the
  # user switches groups between request creation and provision time the wrong
  # group is stamped on the VM.
  #
  # Matrix (from doc/vm_provisioning_group_ownership_analysis.md):
  #
  #   #  | owner_email | owner_group | requester_group | DB current_group | Expected | Status
  #   1  | present     | present     | any             | group_user       | group_user  | Pass (get_owner sets group via current_group_by_description)
  #   2a | present     | present     | any             | group_admin      | group_user  | Pass (same path)
  #   2b | present     | MISSING     | group_user      | group_admin      | group_user  | FAIL (get_owner does not apply owner_group; set_ownership uses DB value)
  #   3  | present     | present     | any             | group_admin      | group_admin | Pass (owner_group matches request-time group)
  #   4a | present     | present     | any             | group_user       | group_admin | Pass (get_owner applies owner_group)
  #   4b | present     | MISSING     | group_admin     | group_user       | group_admin | FAIL (same root cause as 2b)
  #   5  | absent      | absent      | group_user      | group_admin      | group_user  | Pass (get_user applies requester_group via current_group_by_description)
  #
  # Scenarios 2b and 4b are the broken cases this fix addresses.

  subject(:ownership) { Object.new.extend(described_module) }

  let(:described_module) { MiqProvision::Ownership }

  # Rather than spinning up a full provision task, test set_ownership directly.
  # Each example sets up a user whose DB current_group differs from the
  # request-time group, then asserts what vm.miq_group should be.

  let(:group_user)  { FactoryBot.create(:miq_group, :description => "user_group")  }
  let(:group_admin) { FactoryBot.create(:miq_group, :description => "admin_group") }
  let(:vm)          { FactoryBot.create(:vm_vmware) }

  describe "#set_ownership" do
    # -------------------------------------------------------------------
    # Scenario 1 / 2a: owner_group present, user did not switch groups.
    # get_owner already called current_group_by_description, so the
    # in-memory user.current_group is group_user.
    # set_ownership must stamp that group on the VM.
    # -------------------------------------------------------------------
    context "when user's in-memory current_group is the request-time group (scenario 1/2a)" do
      it "stamps the request-time group on the VM" do
        user = FactoryBot.create(:user, :miq_groups => [group_user, group_admin], :current_group => group_user)
        # Simulate get_owner having called current_group_by_description already:
        user.current_group_by_description = group_user.description

        ownership.set_ownership(vm, user)

        expect(vm.miq_group).to eq(group_user)
      end
    end

    # -------------------------------------------------------------------
    # Scenario 2b: owner_email present, owner_group MISSING.
    # get_owner finds the user but skips current_group_by_description
    # because owner_group option is blank.  The user's DB current_group
    # is group_admin (switched after request creation).
    # set_ownership must use requester_group / owner_group from options,
    # NOT user.current_group.
    #
    # CURRENTLY BROKEN: set_ownership stamps group_admin (DB value)
    # instead of group_user (request-time group).
    # -------------------------------------------------------------------
    context "when owner_group is missing and the user switched to an admin group (scenario 2b)" do
      it "stamps the request-time group (group_user) on the VM, not the switched DB group (group_admin)" do
        user = FactoryBot.create(:user, :miq_groups => [group_user, group_admin], :current_group => group_admin)
        # No owner_group override was applied -- user.current_group is DB value (group_admin).
        # The caller should pass the resolved group explicitly; set_ownership should use it.
        # Expected: group_user.  Currently broken: group_admin is stamped instead.

        ownership.set_ownership(vm, user, group_user)

        expect(vm.miq_group).to eq(group_user)
      end
    end

    # -------------------------------------------------------------------
    # Scenario 3: request created in group_admin, user still in group_admin.
    # No group change -- expected result is group_admin.
    # -------------------------------------------------------------------
    context "when the user's current_group matches the request-time group (scenario 3)" do
      it "stamps group_admin on the VM" do
        user = FactoryBot.create(:user, :miq_groups => [group_user, group_admin], :current_group => group_admin)

        ownership.set_ownership(vm, user, group_admin)

        expect(vm.miq_group).to eq(group_admin)
      end
    end

    # -------------------------------------------------------------------
    # Scenario 4b: owner_email present, owner_group MISSING.
    # Request created in group_admin; user later switched to group_user.
    # set_ownership must not use the switched DB group.
    #
    # CURRENTLY BROKEN: group_user (DB value) is stamped instead of
    # group_admin (request-time group).
    # -------------------------------------------------------------------
    context "when owner_group is missing and the user switched to a user group (scenario 4b)" do
      it "stamps the request-time group (group_admin) on the VM, not the switched DB group (group_user)" do
        user = FactoryBot.create(:user, :miq_groups => [group_user, group_admin], :current_group => group_user)
        # No owner_group override applied -- user.current_group is DB value (group_user).
        # Expected: group_admin.  Currently broken: group_user is stamped instead.

        ownership.set_ownership(vm, user, group_admin)

        expect(vm.miq_group).to eq(group_admin)
      end
    end

    # -------------------------------------------------------------------
    # Scenario 5: no owner_email.  get_user is called; it applies
    # requester_group via current_group_by_description.
    # The in-memory user.current_group is already group_user.
    # set_ownership must stamp group_user.
    # -------------------------------------------------------------------
    context "when the resolved group is explicitly provided (scenario 5 / requester_group path)" do
      it "stamps the explicitly provided group on the VM" do
        user = FactoryBot.create(:user, :miq_groups => [group_user, group_admin], :current_group => group_admin)
        # Simulate get_user having applied requester_group:
        user.current_group_by_description = group_user.description

        ownership.set_ownership(vm, user, group_user)

        expect(vm.miq_group).to eq(group_user)
      end
    end

    # -------------------------------------------------------------------
    # Fallback: no explicit group and user.current_group is the only info
    # available.  set_ownership must still set evm_owner and fall back to
    # user.current_group.
    # -------------------------------------------------------------------
    context "when no resolved group is provided (fallback to user.current_group)" do
      it "stamps user.current_group on the VM" do
        user = FactoryBot.create(:user, :miq_groups => [group_user], :current_group => group_user)

        ownership.set_ownership(vm, user, nil)

        expect(vm.evm_owner).to eq(user)
        expect(vm.miq_group).to eq(group_user)
      end
    end
  end
end
