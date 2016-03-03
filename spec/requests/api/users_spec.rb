# Rest API Request Tests - Users specs
#
# - Creating a user                      /api/users                           POST
# - Creating a user via action           /api/users                           action "create"
# - Creating multiple user               /api/users                           action "create"
# - Edit a user                          /api/users/:id                       action "edit"
# - Edit multiple users                  /api/users                           action "edit"
# - Delete a user                        /api/users/:id                       DELETE
# - Delete a user by action              /api/users/:id                       action "delete"
# - Delete multiple users                /api/users                           action "delete"
#
RSpec.describe "users API" do
  let(:expected_attributes) { %w(id name userid current_group_id) }

  let(:tenant1)  { FactoryGirl.create(:tenant, :name => "Tenant1") }
  let(:role1)    { FactoryGirl.create(:miq_user_role) }
  let(:group1)   { FactoryGirl.create(:miq_group, :description => "Group1", :role => role1, :tenant => tenant1) }

  let(:role2)    { FactoryGirl.create(:miq_user_role) }
  let(:group2)   { FactoryGirl.create(:miq_group, :description => "Group2", :role => role2, :tenant => tenant1) }

  let(:sample_user1) { {:userid => "user1", :name => "User1", :password => "password1", :group => {"id" => group1.id}} }
  let(:sample_user2) { {:userid => "user2", :name => "User2", :password => "password2", :group => {"id" => group2.id}} }

  let(:user1) { FactoryGirl.create(:user, sample_user1.except(:group).merge(:miq_groups => [group1])) }
  let(:user2) { FactoryGirl.create(:user, sample_user2.except(:group).merge(:miq_groups => [group2])) }

  context "with an appropriate role" do
    it "can change the user's password" do
      api_basic_authorize action_identifier(:users, :edit)

      expect do
        run_post users_url(@user.id), gen_request(:edit, :password => "new_password")
      end.to change { @user.reload.password_digest }

      expect_request_success
    end

    it "can change another user's password" do
      api_basic_authorize action_identifier(:users, :edit)
      user = FactoryGirl.create(:user)

      expect do
        run_post users_url(user.id), gen_request(:edit, :password => "new_password")
      end.to change { user.reload.password_digest }

      expect_request_success
    end
  end

  context "without an appropriate role" do
    it "can change the user's own password" do
      api_basic_authorize

      expect do
        run_post users_url(@user.id), gen_request(:edit, :password => "new_password")
      end.to change { @user.reload.password_digest }

      expect_request_success
    end

    it "will not allow the changing of attributes other than the password" do
      api_basic_authorize

      expect do
        run_post users_url(@user.id), gen_request(:edit, :email => "new.email@example.com")
      end.not_to change { @user.reload.email }

      expect_bad_request
    end

    it "cannot change another user's password" do
      api_basic_authorize
      user = FactoryGirl.create(:user)

      expect do
        run_post users_url(user.id), gen_request(:edit, :password => "new_password")
      end.not_to change { user.reload.password_digest }

      expect_request_forbidden
    end
  end

  describe "users create" do
    it "rejects creation without appropriate role" do
      api_basic_authorize

      run_post(users_url, sample_user1)

      expect_request_forbidden
    end

    it "rejects user creation with id specified" do
      api_basic_authorize collection_action_identifier(:users, :create)

      run_post(users_url, "userid" => "userid1", "id" => 100)

      expect_bad_request(/id or href should not be specified/i)
    end

    it "rejects user creation with invalid group specified" do
      api_basic_authorize collection_action_identifier(:users, :create)

      run_post(users_url, sample_user2.merge("group" => {"id" => 999_999}))

      expect_resource_not_found
    end

    it "rejects user creation with missing attribute" do
      api_basic_authorize collection_action_identifier(:users, :create)

      run_post(users_url, sample_user2.except(:userid))

      expect_bad_request(/Missing attribute/i)
    end

    it "supports single user creation" do
      api_basic_authorize collection_action_identifier(:users, :create)

      run_post(users_url, sample_user1)

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)

      user_id = result["results"].first["id"]
      expect(User.exists?(user_id)).to be_truthy
    end

    it "supports single user creation via action" do
      api_basic_authorize collection_action_identifier(:users, :create)

      run_post(users_url, gen_request(:create, sample_user1))

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)

      user_id = result["results"].first["id"]
      expect(User.exists?(user_id)).to be_truthy
    end

    it "supports multiple user creation" do
      api_basic_authorize collection_action_identifier(:users, :create)

      run_post(users_url, gen_request(:create, [sample_user1, sample_user2]))

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)

      results = result["results"]
      user1_hash, user2_hash = results.first, results.second
      expect(User.exists?(user1_hash["id"])).to be_truthy
      expect(User.exists?(user2_hash["id"])).to be_truthy
      expect(user1_hash["current_group_id"]).to eq(group1.id)
      expect(user2_hash["current_group_id"]).to eq(group2.id)
    end
  end

  describe "users edit" do
    it "rejects user edits without appropriate role" do
      api_basic_authorize

      run_post(users_url, gen_request(:edit, "name" => "updated name", "href" => users_url(user1.id)))

      expect_request_forbidden
    end

    it "rejects user edits for invalid resources" do
      api_basic_authorize collection_action_identifier(:users, :edit)

      run_post(users_url(999_999), gen_request(:edit, "name" => "updated name"))

      expect_resource_not_found
    end

    it "supports single user edit" do
      api_basic_authorize collection_action_identifier(:users, :edit)

      run_post(users_url(user1.id), gen_request(:edit, "name" => "updated name"))

      expect_single_resource_query("id" => user1.id, "name" => "updated name")
      expect(user1.reload.name).to eq("updated name")
    end

    it "supports single user edit of other attributes including group change" do
      api_basic_authorize collection_action_identifier(:users, :edit)

      run_post(users_url(user1.id), gen_request(:edit,
                                                "email" => "user1@email.com",
                                                "group" => {"description" => group2.description}))

      expect_single_resource_query("id" => user1.id, "email" => "user1@email.com", "current_group_id" => group2.id)
      expect(user1.reload.email).to eq("user1@email.com")
      expect(user1.reload.current_group_id).to eq(group2.id)
    end

    it "supports multiple user edits" do
      api_basic_authorize collection_action_identifier(:users, :edit)

      run_post(users_url, gen_request(:edit,
                                      [{"href" => users_url(user1.id), "first_name" => "John"},
                                       {"href" => users_url(user2.id), "first_name" => "Jane"}]))

      expect_results_to_match_hash("results",
                                   [{"id" => user1.id, "first_name" => "John"},
                                    {"id" => user2.id, "first_name" => "Jane"}])

      expect(user1.reload.first_name).to eq("John")
      expect(user2.reload.first_name).to eq("Jane")
    end
  end

  describe "users delete" do
    it "rejects user deletion, by post action, without appropriate role" do
      api_basic_authorize

      run_post(users_url, gen_request(:delete, "href" => users_url(100)))

      expect_request_forbidden
    end

    it "rejects user deletion without appropriate role" do
      api_basic_authorize

      run_delete(users_url(100))

      expect_request_forbidden
    end

    it "rejects user deletes for invalid users" do
      api_basic_authorize collection_action_identifier(:users, :delete)

      run_delete(users_url(999_999))

      expect_resource_not_found
    end

    it "rejects user delete of requesting user via action" do
      api_basic_authorize collection_action_identifier(:users, :delete)

      run_post(users_url, gen_request(:delete, "href" => users_url(@user.id)))

      expect_bad_request("Cannot delete user of current request")
    end

    it "rejects user delete of requesting user" do
      api_basic_authorize collection_action_identifier(:users, :delete)

      run_delete(users_url(@user.id))

      expect_bad_request("Cannot delete user of current request")
    end

    it "supports single user delete" do
      api_basic_authorize collection_action_identifier(:users, :delete)

      user1_id = user1.id
      run_delete(users_url(user1_id))

      expect_request_success_with_no_content
      expect(User.exists?(user1_id)).to be_falsey
    end

    it "supports single user delete action" do
      api_basic_authorize collection_action_identifier(:users, :delete)

      user1_id = user1.id
      user1_url = users_url(user1_id)

      run_post(user1_url, gen_request(:delete))

      expect_single_action_result(:success => true, :message => "deleting", :href => user1_url)
      expect(User.exists?(user1_id)).to be_falsey
    end

    it "supports multiple user deletes" do
      api_basic_authorize collection_action_identifier(:users, :delete)

      user1_id, user2_id = user1.id, user2.id
      user1_url, user2_url = users_url(user1_id), users_url(user2_id)

      run_post(users_url, gen_request(:delete, [{"href" => user1_url}, {"href" => user2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", [user1_url, user2_url])
      expect(User.exists?(user1_id)).to be_falsey
      expect(User.exists?(user2_id)).to be_falsey
    end
  end
end
