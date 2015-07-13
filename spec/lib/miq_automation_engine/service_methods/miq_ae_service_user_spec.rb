require 'spec_helper'

module MiqAeServiceUserSpec
  describe MiqAeMethodService::MiqAeServiceUser do
    let(:user)         { FactoryGirl.create(:user_admin) }
    let(:service_user) { MiqAeMethodService::MiqAeServiceUser.find(user.id) }

    ["current_group", "miq_group"].each do |group|
      it "##{group}" do
        user # create before setting expectation
        User.any_instance.should_receive(:current_group).and_call_original
        expect(service_user.send(group)).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqGroup)
      end
    end
  end
end
