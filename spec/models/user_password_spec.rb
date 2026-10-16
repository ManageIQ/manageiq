require 'bcrypt'

RSpec.describe User, "password" do
  let(:strong_password)  { "Tr0ub4dor&3" } # Score 4 — zxcvbn rates this very strong
  let(:weak_password)    { "password" }    # Score 0 — top-10 common password
  let(:smartvm_password) { "smartvm" }     # Score 1 — low entropy, the default admin seed password

  # Build a user record without persisting; password= triggers the virtual attr
  def build_user(password)
    FactoryBot.build(:user, :password => password)
  end

  context "with admin user" do
    before do
      EvmSpecHelper.local_miq_server

      @old = smartvm_password
      @admin = FactoryBot.create(:user, :userid          => 'admin',
                                        :password_digest => BCrypt::Password.create(@old))
    end

    it "has set password" do
      expect(@admin.authenticate_bcrypt(@old)).to eq(@admin)
    end

    context "call change_password" do
      before do
        @admin.change_password(@old, strong_password)
      end

      it "changes password" do
        expect(@admin.authenticate_bcrypt(strong_password)).to eq(@admin)
      end
    end

    context "call password=" do
      before do
        @admin.password = strong_password
        @admin.save!
      end

      it "changes password" do
        expect(@admin.authenticate_bcrypt(strong_password)).to eq(@admin)
      end
    end
  end

  context "complexity" do
    context "with default settings (min_score 3)" do
      it "accepts a strong password (score 4)" do
        expect(build_user(strong_password)).to be_valid
      end

      it "rejects a weak password (score 0)" do
        user = build_user(weak_password)
        expect(user).not_to be_valid
        expect(user.errors[:base].first).to include("Password is not strong enough")
      end

      it "includes zxcvbn feedback in the base error message" do
        user = build_user("P@ssw0rd")
        user.valid?
        message = user.errors[:base].first
        expect(message).to include("Password is not strong enough")
        expect(message).to include("This is similar to a commonly used password")
        expect(message).to include("Predictable substitutions like '@' instead of 'a' don't help very much")
      end

      it "rejects a hardcoded ManageIQ term (manageiq)" do
        expect(build_user("manageiq")).not_to be_valid
      end

      it "rejects a hardcoded ManageIQ term (miq)" do
        expect(build_user("miq12345")).not_to be_valid
      end

      it "rejects a hardcoded ManageIQ term (vmdb)" do
        expect(build_user("vmdb1234")).not_to be_valid
      end

      it "rejects smartvm as weak (score 1, below default min_score 3)" do
        expect(build_user(smartvm_password)).not_to be_valid
      end

      it "rejects a common substitution pattern (P@ssw0rd, score 0)" do
        expect(build_user("P@ssw0rd")).not_to be_valid
      end

      context "with skip_complexity_check set" do
        it "allows a weak password" do
          user = build_user(smartvm_password)
          user.skip_complexity_check = true
          expect(user).to be_valid
        end
      end

      context "when no password is being set" do
        it "does not run the complexity check" do
          # password_digest set directly; the password virtual attr is never touched
          user = FactoryBot.build(:user, :password_digest => "$2a$10$FTbGT/y/PQ1HvoOoc1FcyuuTtHzfop/uG/mcEAJLYpzmsUIJcGT7W")
          expect(user).to be_valid
        end
      end
    end

    context "when min_score is 0 (enforcement disabled)" do
      before { stub_settings_merge(:authentication => {:password_rules => {:complexity_min_score => 0}}) }

      it "accepts a weak password" do
        expect(build_user(weak_password)).to be_valid
      end

      it "accepts smartvm" do
        expect(build_user(smartvm_password)).to be_valid
      end
    end

    context "with min_score lowered to 1" do
      before { stub_settings_merge(:authentication => {:password_rules => {:complexity_min_score => 1}}) }

      it "accepts smartvm (score 1) when the bar is low enough" do
        expect(build_user(smartvm_password)).to be_valid
      end

      it "still rejects a score-0 password" do
        expect(build_user(weak_password)).not_to be_valid
      end
    end

    context "with operator-defined extra words" do
      before do
        stub_settings_merge(:authentication => {:password_rules => {:complexity_extra_words => %w[acme corp]}})
      end

      it "rejects a password based on an operator-defined term" do
        expect(build_user("acme1234")).not_to be_valid
      end

      it "still accepts a strong password unrelated to the extra words" do
        expect(build_user(strong_password)).to be_valid
      end
    end

    context "User.seed" do
      # User.seed sets skip_complexity_check so the weak default password is
      # accepted during first boot without disabling enforcement globally.
      it "seeds the admin user successfully" do
        User.seed
        expect(User.find_by(:userid => "admin")).to be_present
      end
    end

    context "operator-generated admin password" do
      # The manageiq-operator generates passwords as RawURLEncoding(randomBytes(12))
      # - 16 URL-safe base64 chars from the alphabet [A-Za-z0-9_-]. The wide character
      # set ensures all outputs score 4 on zxcvbn regardless of the random content.
      it "accepts any generated password" do
        expect(build_user("QFzUfycaksV9Ctg_")).to be_valid
      end
    end
  end
end
