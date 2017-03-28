describe MiqRequestTask do
  context "::Dumping" do
    let(:task) { FactoryGirl.create(:miq_request_task) }

    describe '#dump_obj' do
      it "calls .dump_obj" do
        expect(task.class).to receive(:dump_obj)
        task.dump_obj(:param_1 => 1)
      end

      it 'hides passwords' do
        expect($log).to receive(:info).with(/<PROTECTED>/)
        task.dump_obj({:my_password => "secret"}, "my choices: ", $log, :info, :protected => {:path => /[Pp]assword/})
      end
    end

    describe '.dump_obj' do
      it 'accepts a hash' do
        expect(task.class).to receive(:dump_hash)
        task.class.dump_obj(:param_1 => 1)
      end

      it 'accepts an array' do
        expect(task.class).to receive(:dump_array)
        task.class.dump_obj(%w(1 2 3))
      end
    end

    it '#dump_vim_hash' do
      data = VimHash.new('VirtualDisk') do |vh|
        vh.backing = {'diskMode' => 'persistent', 'datastore' => 'datastore-001'}
        vh.capacityInKB = 100
      end
      expect(MiqRequestTask).to receive(:dump_hash)
      task.dump_obj(data)
    end

    it '#dump_vim_array' do
      array = VimArray.new("ArrayOfHostInternetScsiHbaStaticTarget") do |ta|
        ta << VimHash.new("HostInternetScsiHbaStaticTarget") do |st|
          st.address    = "10.1.1.210"
          st.iScsiName  = "iqn.1992-08.com.netapp:sn.135107242"
        end
        ta << VimHash.new("HostInternetScsiHbaStaticTarget") do |st|
          st.address    = "10.1.1.100"
          st.iScsiName  = "iqn.2008-08.com.starwindsoftware:starwindm1-starm1-test1"
        end
      end
      expect(MiqRequestTask).to receive(:dump_array)
      task.dump_obj(array)
    end
  end
end
