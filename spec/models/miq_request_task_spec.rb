describe MiqRequestTask do
  let(:existing_options) { {'a' => 1, 'b' => 2} }
  let(:new_options) { {'a' => 'one', 'c' => 'three'} }
  let(:miq_request) do
    FactoryGirl.build(:miq_host_provision_request,
                      :requester => user,
                      :options   => existing_options)
  end

  let(:task) do
    FactoryGirl.create(:miq_request_task,
                       :miq_request => miq_request,
                       :options     => existing_options)
  end
  let(:user) { FactoryGirl.build(:user) }

  context "#update_request_task" do
    it "updates the option hash" do
      task.update_request_task('options' => new_options)

      expect(task.options).to have_attributes(existing_options.merge(new_options))
    end
  end
end
