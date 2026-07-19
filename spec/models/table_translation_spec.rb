# frozen_string_literal: true

require 'spec_helper'

describe TableTranslation do
  include SpecSupport::TableTranslationHelper

  let(:expected_table_entries) { extract_table_entries('spec/fixtures/locale/en.yml') }

  it 'checks for missing table entries' do
    table_entries = extract_table_entries('spec/fixtures/locale/en.yml')
    missing_entries = expected_table_entries - table_entries
    expect(missing_entries).to be_empty
  end
end