describe 'FactoryGirl' do
  let(:local_models) { Dir.glob('app/models/*.rb').map { |file| File.basename(file, '.rb').to_sym } }

  it 'All models have a factory defined' do
    expect(FactoryGirl.factories.map { |x| x.name.to_sym } & local_models).to match_array(local_models)
  end
end
