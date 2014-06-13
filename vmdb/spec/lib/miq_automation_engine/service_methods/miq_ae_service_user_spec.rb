require 'spec_helper'

module MiqAeServiceUserSpec
  describe MiqAeMethodService::MiqAeServiceUser do
    let(:user)         { FactoryGirl.create(:user) }
    let(:service_user) { MiqAeMethodService::MiqAeServiceUser.find(user.id) }

    it "#current_group" do
      user # create before setting expectation
      User.any_instance.should_receive(:current_group)
      service_user.current_group
    end

    it "#miq_group" do
      user # create before setting expectation
      User.any_instance.should_receive(:current_group)
      service_user.miq_group
    end
  end
end
