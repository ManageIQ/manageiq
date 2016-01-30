describe DashboardController do
  let(:user) do
    FactoryGirl.create(:user_with_email, :password => "smartvm", :role => "super_administrator")
  end

  before(:each) do
    EvmSpecHelper.local_miq_server
    user
  end

  let(:valid_user) do
    {
      :name            => user.userid,
      :password        => 'smartvm',
      :new_password    => nil,
      :verify_password => nil,
    }
  end

  let(:invalid_password) do
    {
      :name            => user.userid,
      :password        => 'foobar',
      :new_password    => nil,
      :verify_password => nil,
    }
  end

  let(:invalid_user) do
    {
      :name            => 'boofar',
      :password        => 'foobar',
      :new_password    => nil,
      :verify_password => nil,
    }
  end

  let(:valid_password_change) do
    {
      :new_password    => 'zaserthzkslt3',
      :verify_password => 'zaserthzkslt3',
    }
  end

  let(:invalid_password_change) do
    {
      :new_password    => 'zaserthzkslt2',
      :verify_password => 'zaserthzkslt3',
    }
  end

  let(:only_blanks_password_change) do
    {
      :new_password    => '   ',
      :verify_password => '   ',
    }
  end

  context "validate_user" do
    it 'succeeds for a valid user' do
      validation = controller.send(:validate_user, valid_user, nil)
      expect(validation.result).to eq(:pass)
      expect(validation.url).not_to be_nil
    end

    it 'fails for an existing user with wrong password' do
      validation = controller.send(:validate_user, invalid_password, nil)
      expect(validation.result).to eq(:fail)
      expect(validation.flash_msg).to eq("Sorry, the username or password you entered is incorrect.")
      expect(validation.url).to be_nil
    end

    it 'fails for an invalid user' do
      validation = controller.send(:validate_user, invalid_user, nil)
      expect(validation.result).to eq(:fail)
      expect(validation.flash_msg).to eq("Sorry, the username or password you entered is incorrect.")
      expect(validation.url).to be_nil
    end

    it 'succeeds for valid user with valid password change' do
      validation = controller.send(:validate_user,
                                   valid_user.merge(valid_password_change), nil)
      expect(validation.result).to eq(:pass)
    end

    it 'fails for invalid user with valid password change' do
      validation = controller.send(:validate_user,
                                   invalid_password.merge(valid_password_change), nil)
      expect(validation.result).to eq(:fail)
    end

    it 'fails for valid user with invalid password change' do
      validation = controller.send(:validate_user,
                                   valid_user.merge(invalid_password_change), nil)
      expect(validation.result).to eq(:fail)
      expect(validation.flash_msg).to eq('Error: New password and verify password must be the same')
      expect(validation.url).to be_nil
    end

    it 'fails for a valid user for a change to a blank password' do
      validation = controller.send(:validate_user, valid_user.merge(only_blanks_password_change), nil)
      expect(validation.result).to eq(:fail)
      expect(validation.flash_msg).to eq("Error: New password can not be blank")
      expect(validation.url).to be_nil
    end
  end
end
