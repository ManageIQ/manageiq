RSpec.describe MiqDatabase do
  describe ".encrypted_columns" do
    it "returns the encrypted columns" do
      expected = %w[csrf_secret_token session_secret_token]
      expect(described_class.encrypted_columns).to match_array(expected)
    end
  end

  let(:db) { described_class.seed }

  let!(:region) do
    FactoryBot.create(:miq_region, :region => ApplicationRecord.my_region_number)
  end

  context ".registration_default_value_for_update_repo_name" do
    it "returns an empty array if the setting is not set" do
      expect(described_class.registration_default_value_for_update_repo_name).to eq("")
    end

    it "returns the template repos as a string when the setting is set" do
      stub_template_settings(:product => {:update_repo_names => %w(repo-1 repo-2)})
      stub_settings(:product => {:update_repo_names => %w(repo-3 repo-4)})

      expect(described_class.registration_default_value_for_update_repo_name).to eq("repo-1 repo-2")
    end
  end

  context "#update_repo_names" do
    it "returns an empty array by default" do
      expect(db.update_repo_names).to eq([])
    end

    it "returns the repos as an array when the setting is set" do
      repo_names = %w(repo-1 repo-2)
      stub_settings(:product => {:update_repo_names => repo_names})

      expect(db.update_repo_names).to eq(repo_names)
    end
  end

  context "#update_repo_name" do
    it "returns an empty string by default" do
      expect(db.update_repo_name).to eq("")
    end

    it "returns the repos as a string when the setting is set" do
      repo_names = %w(repo-1 repo-2)
      stub_settings(:product => {:update_repo_names => repo_names})

      expect(db.update_repo_name).to eq("repo-1 repo-2")
    end
  end

  context "#update_repo_name=" do
    it "sets the update repo names in the setting hash" do
      db.update_repo_name = "repo-1 repo-2"
      expect(Vmdb::Settings.for_resource(region).product.update_repo_names).to eq(%w(repo-1 repo-2))
    end
  end

  context ".seed" do
    include_examples ".seed called multiple times", 1

    context "default values" do
      it "new record" do
        db = MiqDatabase.seed
        expect(db.csrf_secret_token_encrypted).to be_encrypted
        expect(db.session_secret_token_encrypted).to be_encrypted
      end

      context "existing record" do
        it "will seed nil values" do
          FactoryBot.build(:miq_database,
                            :csrf_secret_token    => nil,
                            :session_secret_token => nil
                           ).save(:validate => false)

          db = MiqDatabase.seed
          expect(db.csrf_secret_token_encrypted).to be_encrypted
          expect(db.session_secret_token_encrypted).to be_encrypted
        end

        it "will not change existing values" do
          FactoryBot.create(:miq_database,
                             :csrf_secret_token    => "abc",
                             :session_secret_token => "def"
                            )
          csrf, session, update_repo = MiqDatabase.all.collect { |db| [db.csrf_secret_token, db.session_secret_token, db.update_repo_name] }.first

          db = MiqDatabase.seed
          expect(db.csrf_secret_token).to eq(csrf)
          expect(db.session_secret_token).to eq(session)
          expect(db.update_repo_name).to eq(update_repo)
        end
      end
    end
  end

  if ENV.key?("CI")
    it "uses a random, non-zero, region number on Travis" do
      db = MiqDatabase.seed
      expect(db.region_number).to be > 0
      expect(db.region_number).to eq(MiqRegion.my_region_number)
    end
  end
end
