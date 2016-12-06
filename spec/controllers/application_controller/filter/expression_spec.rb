describe ApplicationController::Filter do
  describe '#available_adv_searches' do
    let(:user)           { FactoryGirl.create(:user) }
    let!(:user_search)   { FactoryGirl.create(:miq_search_user, :search_key => user.userid) }
    let!(:user_search2)  { FactoryGirl.create(:miq_search_user, :search_key => user.userid) }
    let(:expression)     { ApplicationController::Filter::Expression.new.tap { |e| e.exp_model = 'Vm' } }

    before do
      allow(User).to receive(:current_user).and_return(user)
    end

    it 'returns user searches' do
      expect(expression.available_adv_searches).to eq [
        [user_search.description,  user_search.id],
        [user_search2.description, user_search2.id]
      ]
    end

    context 'with global searches' do
      let!(:global_search)  { FactoryGirl.create(:miq_search_global) }
      let!(:global_search2) { FactoryGirl.create(:miq_search_global) }

      it 'returns global searches and then user searches' do
        expect(expression.available_adv_searches).to eq [
          ["Global - #{global_search.description}",  global_search.id],
          ["Global - #{global_search2.description}", global_search2.id],
          [user_search.description,                  user_search.id],
          [user_search2.description,                 user_search2.id]
        ]
      end
    end

    it 'does not include searches from other users' do
      FactoryGirl.create(:miq_search_user, :search_key => -1) # A search from another "user"

      expect(expression.available_adv_searches).to eq [
        [user_search.description,  user_search.id],
        [user_search2.description, user_search2.id]
      ]
    end
  end
end
