describe MiqRequestTask do
  let(:options) { {'a' => 1, 'b' => 2} }
  let(:update_options) { {'a' => 'one', 'c' => 'three'} }
  let(:miq_request) do
    FactoryGirl.build(:miq_host_provision_request,
                      :requester => user,
                      :options   => options)
  end

  let(:task) do
    FactoryGirl.create(:miq_request_task,
                       :miq_request => miq_request,
                       :options     => options)
  end
  let(:user) { FactoryGirl.build(:user) }

  context "#update_request_task" do
    it "updates the option hash" do
      task.update_request_task('options' => update_options)

      expect(task.options).to have_attributes(options.merge(update_options))
    end
  end
end
