require 'spec_helper'

describe 'routes for ConfigurationController' do
  describe '#change_tab' do
    it 'routes' do
      expect(get('/configuration/change_tab')).to route_to('configuration#change_tab')
    end
  end

  describe '#index' do
    it 'routes with get' do
      expect(get('/configuration')).to route_to('configuration#index')
    end
  end

  describe '#show' do
    it 'routes' do
      expect(get('/configuration/show')).to route_to('configuration#show')
    end
  end

  describe '#timeprofile_copy' do
    it 'routes' do
      expect(get('/configuration/timeprofile_copy')).to route_to('configuration#timeprofile_copy')
    end
  end

  describe '#timeprofile_edit' do
    it 'routes' do
      expect(get('/configuration/timeprofile_edit')).to route_to('configuration#timeprofile_edit')
    end
  end

  describe '#timeprofile_new' do
    it 'routes' do
      expect(get('/configuration/timeprofile_new')).to route_to('configuration#timeprofile_new')
    end
  end

  describe '#button' do
    it 'routes' do
      expect(post('/configuration/button')).to route_to('configuration#button')
    end
  end

  describe '#filters_field_changed' do
    it 'routes' do
      expect(post('/configuration/filters_field_changed')).to route_to('configuration#filters_field_changed')
    end
  end

  describe '#form_field_changed' do
    it 'routes' do
      expect(post('/configuration/form_field_changed')).to route_to('configuration#form_field_changed')
    end
  end

  describe '#theme_changed' do
    it 'routes' do
      expect(post('/configuration/theme_changed')).to route_to('configuration#theme_changed')
    end
  end

  describe '#timeprofile_create' do
    it 'routes' do
      expect(post('/configuration/timeprofile_create')).to route_to('configuration#timeprofile_create')
    end
  end

  describe '#timeprofile_delete' do
    it 'routes' do
      expect(post('/configuration/timeprofile_delete')).to route_to('configuration#timeprofile_delete')
    end
  end

  describe '#timeprofile_field_changed' do
    it 'routes' do
      expect(post('/configuration/timeprofile_field_changed')).to route_to('configuration#timeprofile_field_changed')
    end
  end

  describe '#timeprofile_update' do
    it 'routes' do
      expect(post('/configuration/timeprofile_update')).to route_to('configuration#timeprofile_update')
    end
  end

  describe '#update' do
    it 'routes' do
      expect(post('/configuration/update')).to route_to('configuration#update')
    end
  end

  describe '#view_selected' do
    it 'routes' do
      expect(post('/configuration/view_selected')).to route_to('configuration#view_selected')
    end
  end
end
