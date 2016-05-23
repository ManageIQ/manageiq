describe ProviderForemanHelper do

  before do

    @record = FactoryGirl.create(:ansible_configuration_script,
                                            :name => "ConfigScript1",
                                            :survey_spec => { 'spec'=> [{'index' => 0,'question_description' => 'Survey', 'min' => nil,
                                                              'default' => nil, 'max' => nil,
                                                              'question_name' => 'Survey', 'required' => false,
                                                              'variable' => 'test', 'choices' => nil, 'type' => 'text'}]})

    login_as @user = FactoryGirl.create(:user)
  end

   context ".textual_configuration_script_survey" do
      subject { textual_configuration_script_survey }

      it 'shows the survey spec paramters' do
        expect(subject[:headers]).to match_array([_('Question Name'), _('Question Description'), _('Variable'),
                                    _('Type'),  _('Min'), _('Max'), _('Default'), _('Required'), _('Choices')])
        expect(subject[:value]).to match_array([{:title => 0, :question_name => 'Survey',
                                                 :question_description => 'Survey', :variable => 'test',
                                                 :type => 'text', :min => nil, :max => nil, :default => nil,
                                                 :required => false, :choices => nil}])
      end
    end
end
