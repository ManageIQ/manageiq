require 'rake'

describe 'evm_export_import' do
  let(:task_path) {'lib/tasks/evm_export_import'}

  describe 'evm:import:alerts', :type => :rake_task do
    it 'depends on the environment' do
      expect(Rake::Task['evm:import:alerts'].prerequisites).to include('environment')
    end
  end

  describe 'evm:import:alertprofiles', :type => :rake_task do
    it 'depends on the environment' do
      expect(Rake::Task['evm:import:alertprofiles'].prerequisites).to include('environment')
    end
  end

  describe 'evm:export:alerts', :type => :rake_task do
    it 'depends on the environment' do
      expect(Rake::Task['evm:export:alerts'].prerequisites).to include('environment')
    end
  end

  describe 'evm:export:alertprofiless', :type => :rake_task do
    it 'depends on the environment' do
      expect(Rake::Task['evm:export:alertprofiles'].prerequisites).to include('environment')
    end
  end
end
