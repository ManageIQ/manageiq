shared_examples_for "OwnershipMixin" do
  context "includes OwnershipMixin" do
    include Spec::Support::ArelHelper

    let(:user) do
      FactoryBot.create(:user,
                         :userid     => "ownership_user",
                         :miq_groups => FactoryBot.create_list(:miq_group, 1))
    end

    let(:user2)  { FactoryBot.create(:user) }
    let(:group)  { user.current_group }
    let(:group2) { FactoryBot.create(:miq_group) }

    let(:factory) { described_class.to_s.underscore.to_sym }

    let!(:in_ldap)     { FactoryBot.create(factory, :name => "in_ldap",     :miq_group => group) }
    let!(:not_in_ldap) { FactoryBot.create(factory, :name => "not_in_ldap", :miq_group => group2) }
    let!(:no_group)    { FactoryBot.create(factory, :name => "no_group") }
    let!(:user_owned)  { FactoryBot.create(factory, :name => "user_owned",  :evm_owner => user) }
    let!(:user_owned2) { FactoryBot.create(factory, :name => "user_owned2", :evm_owner => user2) }

    describe ".user_or_group_owned" do
      let(:user_other_region) do
        other_region_id = ApplicationRecord.id_in_region(1, MiqRegion.my_region_number + 1)
        FactoryBot.create(:user, :id => other_region_id).tap do |u|
          u.update_column(:userid, user.userid) # Bypass validation for test purposes
        end
      end

      let(:group_other_region) do
        other_region_id = ApplicationRecord.id_in_region(1, MiqRegion.my_region_number + 1)
        FactoryBot.create(:miq_group, :id => other_region_id).tap do |g|
          g.update_column(:description, group.description) # Bypass validation for test purposes
        end
      end

      context "only with a user" do
        it "in this region" do
          expect(described_class.user_or_group_owned(user, nil)).to eq([user_owned])
        end

        it "with mixed case userid" do
          user.update(:userid => "MixedCase")
          expect(described_class.user_or_group_owned(user, nil)).to eq([user_owned])
        end

        it "with same userid as another region" do
          user_owned.update!(:evm_owner => user_other_region)
          expect(described_class.user_or_group_owned(user, nil)).to eq([user_owned])
        end
      end

      context "only with a group" do
        it "in this region" do
          expect(described_class.user_or_group_owned(nil, group)).to eq([in_ldap])
        end

        it "with same group description as another region" do
          in_ldap.update!(:miq_group => group_other_region)
          expect(described_class.user_or_group_owned(nil, group)).to eq([in_ldap])
        end
      end

      context "with a user and a group" do
        it "in this region" do
          expect(described_class.user_or_group_owned(user, group)).to match_array([in_ldap, user_owned])
        end

        it "with same userid as another region" do
          user_owned.update!(:evm_owner => user_other_region)
          expect(described_class.user_or_group_owned(user, group)).to match_array([in_ldap, user_owned])
        end

        it "with same group description as another region" do
          user_owned.update!(:miq_group => group_other_region)
          expect(described_class.user_or_group_owned(user, group)).to match_array([in_ldap, user_owned])
        end
      end
    end

    describe "#owning_ldap_group" do
      let(:column) { :owning_ldap_group }
      before { User.current_user = user }

      context "when miq_group is in the ldap group" do
        it "returns description" do
          query = described_class.where(:name => 'in_ldap')
          expect(virtual_column_sql_value(query, column)).to eq(user.current_group.description)
        end
      end

      context "when miq_group is not in the ldap group" do
        it "returns no description" do
          query = described_class.where(:name => 'no_group')
          expect(virtual_column_sql_value(query, column)).to be_nil
        end
      end
    end

    describe "#owned_by_current_ldap_group" do
      let(:column) { :owned_by_current_ldap_group }
      before { User.current_user = user }

      it "usable as arel" do
        group_name = user.current_group.description.downcase
        sql        = <<-SQL.strip_heredoc.split("\n").join(' ')
                       LOWER((SELECT "miq_groups"."description"
                       FROM "miq_groups"
                       WHERE "miq_groups"."id" = "#{described_class.table_name}"."miq_group_id")) = '#{group_name}'
                     SQL
        attribute  = described_class.arel_attribute(:owned_by_current_ldap_group)
        expect(stringify_arel(attribute)).to eq ["(#{sql})"]
      end

      context "when miq_group is in the ldap group" do
        it "returns true" do
          query = described_class.where(:name => 'in_ldap')
          expect(virtual_column_sql_value(query, column)).to eq(true)
        end
      end

      context "when miq_group is not in the ldap group" do
        it "returns false" do
          query = described_class.where(:name => 'not_in_ldap')
          expect(virtual_column_sql_value(query, column)).to eq(false)
        end
      end

      # Since we are doing a regular inner join here, no results will be returned
      # when there isn't an associated miq_group for the record.
      #
      # This was the existing behaviour of the owned_by_current_ldap_group
      # method, so we are testing that the query (even without the
      # virtual_attribute) will return no records.
      context "when miq_group is in no ldap group" do
        it "returns nil" do
          query = described_class.where(:name => 'no_group')
          expect(virtual_column_sql_value(query, column)).to eq(nil)
        end

        it "returns no results when searching by name and owned_by_current_ldap_group" do
          query = described_class.where(:name => 'no_group', column => false)
          expect(query.to_a.size).to eq(0)
        end
      end
    end

    describe "#evm_owner_name" do
      let(:column) { :evm_owner_name }
      before { User.current_user = user }

      context "when has a user" do
        it "returns userid" do
          query = described_class.where(:name => 'user_owned')
          expect(virtual_column_sql_value(query, column)).to eq(user.name)
        end
      end

      context "when has no user" do
        it "returns no description" do
          query = described_class.where(:name => 'no_group')
          expect(virtual_column_sql_value(query, column)).to be_nil
        end
      end
    end

    describe "#evm_owner_userid" do
      let(:column) { :evm_owner_userid }
      before { User.current_user = user }

      context "when has a user" do
        it "returns userid" do
          query = described_class.where(:name => 'user_owned')
          expect(virtual_column_sql_value(query, column)).to eq(user.userid)
        end
      end

      context "when has no user" do
        it "returns no description" do
          query = described_class.where(:name => 'no_group')
          expect(virtual_column_sql_value(query, column)).to be_nil
        end
      end
    end

    describe "#evm_owner_email" do
      let(:column) { :evm_owner_email }
      before { User.current_user = user }

      context "when has a user" do
        it "returns userid" do
          query = described_class.where(:name => 'user_owned')
          expect(virtual_column_sql_value(query, column)).to eq(user.email)
        end
      end

      context "when has no user" do
        it "returns no description" do
          query = described_class.where(:name => 'no_group')
          expect(virtual_column_sql_value(query, column)).to be_nil
        end
      end
    end

    describe "#owned_by_current_user" do
      let(:column) { :owned_by_current_user }
      before { User.current_user = user }

      it "usable as arel" do
        userid = user.userid.downcase
        sql        = <<-SQL.strip_heredoc.split("\n").join(' ')
                       LOWER((SELECT "users"."userid"
                       FROM "users"
                       WHERE "users"."id" = "#{described_class.table_name}"."evm_owner_id")) = '#{userid}'
                     SQL
        attribute  = described_class.arel_attribute(:owned_by_current_user)
        expect(stringify_arel(attribute)).to eq ["(#{sql})"]
      end

      context "when owned by the current user" do
        it "returns true" do
          query = described_class.where(:name => 'user_owned')
          expect(virtual_column_sql_value(query, column)).to eq(true)
        end
      end

      context "when owned by a different user" do
        it "returns false" do
          query = described_class.where(:name => 'user_owned2')
          expect(virtual_column_sql_value(query, column)).to eq(false)
        end
      end

      context "when no user" do
        it "returns nil" do
          query = described_class.where(:name => 'no_group')
          expect(virtual_column_sql_value(query, column)).to eq(nil)
        end

        it "returns no results when searching by name and owned_by_current_user" do
          query = described_class.where(:name => 'no_group', column => false)
          expect(query.to_a.size).to eq(0)
        end
      end
    end

    describe "reporting on ownership" do
      let(:exp_value) { "true" }
      let(:exp) { { "="=> { "field" => "#{described_class}-owned_by_current_ldap_group", "value" => exp_value } } }
      let(:report) { MiqReport.new.tap { |r| r.db = described_class.to_s } }
      let(:search_opts) { { :filter => MiqExpression.new(exp), :per_page => 20 } }

      before do
        expect(User).to receive(:server_timezone).and_return("UTC")

        # Needs to be done after the groups are created, otherwise the
        # described_class will be auto-assigned with the current user's group
        User.current_user = user
      end

      context "searching by records in current ldap group" do
        it "returns results only part of the miq_group" do
          owned_ids = report.paged_view_search(search_opts).first.map(&:id)
          expect(owned_ids).to match_array [in_ldap.id]
        end
      end

      context "searching by records not in current ldap group" do
        let(:exp_value) { "false" }

        it "returns results not part of the miq_group" do
          owned_ids = report.paged_view_search(search_opts).first.map(&:id)
          expect(owned_ids).to match_array [not_in_ldap.id]
        end
      end

      context "searching on owned by the current user" do
        let(:search_opts) { { :filter => MiqExpression.new(exp), :per_page => 20 } }
        let(:exp) { { "=" => { "field" => "#{described_class}-owned_by_current_user", "value" => "true" } } }

        it "returns results owned by the user" do
          owned_ids = report.paged_view_search(search_opts).first.map(&:id)
          expect(owned_ids).to match_array [user_owned.id]
        end
      end

      context "searching on not owned by the current user" do
        let(:search_opts) { { :filter => MiqExpression.new(exp), :per_page => 20 } }
        let(:exp) { { "=" => { "field" => "#{described_class}-owned_by_current_user", "value" => "false" } } }

        it "returns results not owned by the user, but have an owner" do
          owned_ids = report.paged_view_search(search_opts).first.map(&:id)
          expect(owned_ids).to match_array [user_owned2.id]
        end
      end
    end
  end
end
