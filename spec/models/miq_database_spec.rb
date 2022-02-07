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
          csrf, session, update_repo = MiqDatabase.all.collect { |db| [db.csrf_secret_token, db.session_secret_token] }.first

          db = MiqDatabase.seed
          expect(db.csrf_secret_token).to eq(csrf)
          expect(db.session_secret_token).to eq(session)
        end
      end
    end
  end

  if ENV["CI"]
    it "uses a random, non-zero, region number on CI" do
      db = MiqDatabase.seed
      expect(db.region_number).to be > 0
      expect(db.region_number).to eq(MiqRegion.my_region_number)
    end
  end
end
