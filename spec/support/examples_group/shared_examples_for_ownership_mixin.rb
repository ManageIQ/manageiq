shared_examples "miq ownership" do
  # THIS TOP LEVEL CONTEXT IS REQUIRED because tests that include are database
  # state dependent and require a clean DB.  When used with `include_examples`,
  # the before(:context) and after(:context) in this are run on the same level
  # as the `include_example`'s current context, so more likely than not, it
  # will be included in other tests that aren't part of this example group.
  context "includes mixin:  miq ownership" do
    describe "reporting on ownership" do
      let(:exp_value) { "true" }
      let(:exp) { { "="=> { "field" => "#{described_class}-owned_by_current_ldap_group", "value" => exp_value } } }
      let(:report) { MiqReport.new.tap { |r| r.db = described_class.to_s } }
      let(:search_opts) { { :filter => MiqExpression.new(exp), :per_page => 20 } }
      let(:user)              { User.where(:userid => "ownership_user").first }
      let(:owned_by_group_1)  { described_class.where(:name => 'in_ldap').first }
      let(:owned_by_group_2)  { described_class.where(:name => 'not_in_ldap').first }
      let(:owned_by_group_3)  { described_class.where(:name => 'no_group').first }

      before(:context) do
        build_ownership_users_and_groups
      end

      before do
        expect(User).to receive(:server_timezone).and_return("UTC")

        # Needs to be done after the groups are created, otherwise the
        # described_class will be auto-assigned with the current user's group
        User.current_user = user
      end

      context "searching by records in current ldap group" do
        it "returns results only part of the miq_group" do
          owned_ids = report.paged_view_search(search_opts).first.map(&:id)
          expect(owned_ids).to match_array [owned_by_group_1.id]
        end
      end

      context "searching by records not in current ldap group" do
        let(:exp_value) { "false" }

        it "returns results not part of the miq_group" do
          owned_ids = report.paged_view_search(search_opts).first.map(&:id)
          expect(owned_ids).to match_array [owned_by_group_2.id]
        end
      end

      after(:context) do
        teardown_ownership_users_and_groups
      end

      def build_ownership_users_and_groups
        user = FactoryGirl.create :user,
                                  :userid     => "ownership_user",
                                  :miq_groups => FactoryGirl.create_list(:miq_group, 1)

        factory = described_class.to_s.underscore.to_sym
        FactoryGirl.create factory, :name => "in_ldap",     :miq_group_id => user.current_group.id
        FactoryGirl.create factory, :name => "not_in_ldap", :miq_group => FactoryGirl.create(:miq_group)
        FactoryGirl.create factory, :name => "no_group"
      end

      def teardown_ownership_users_and_groups
        described_class.destroy_all
        User.destroy_all
        MiqGroup.destroy_all
      end
    end
  end
end
