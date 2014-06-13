require 'spec_helper'

describe 'routes for AlertController' do
  describe '#index' do
    it 'routes' do
      expect(get('/alert')).to route_to('alert#index')
    end
  end

  describe '#show_list' do
    it 'routes' do
      expect(get('/alert/show_list')).to route_to('alert#show_list')
    end
  end

  describe '#rss' do
    it 'routes' do
      expect(get('/alert/rss')).to route_to('alert#rss')
    end
  end

  describe '#role_selected' do
    it 'routes' do
      expect(post('/alert/role_selected')).to route_to('alert#role_selected')
    end
  end

  describe '#start_rss' do
    it 'routes' do
      expect(post('/alert/start_rss')).to route_to('alert#start_rss')
    end
  end
end
