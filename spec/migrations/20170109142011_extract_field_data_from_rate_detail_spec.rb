require_migration

describe ExtractFieldDataFromRateDetail do
  class ExtractFieldDataFromRateDetail::ChargebackRateDetailMeasure < ActiveRecord::Base; end

  let(:rate_stub) { migration_stub(:ChargebackRate) }
  let(:detail_stub) { migration_stub(:ChargebackRateDetail) }
  let(:field_stub) { migration_stub(:ChargeableField) }
  let(:measure_stub) { migration_stub(:ChargebackRateDetailMeasure) }

  let(:default_rate) { rate_stub.create!(:rate_type => 'Compute', :default => :true) }
  let(:custom_rate) { rate_stub.create!(:rate_type => 'Compute') }
  let(:measure_mhz) { measure_stub.create!(:name => 'Hz Units') }
  let(:measure_bps) { measure_stub.create!(:name => 'Bytes per Second Units') }

  let(:fields) do
    [
      {:metric => 'cpu_usagemhz_rate_average', :group => 'cpu', :source => 'used', :description => 'Used CPU',
       :chargeback_rate_detail_measure_id => measure_mhz.id},
      {:metric => 'derived_vm_numvcpus', :group => 'cpu', :source => 'allocated', :description => 'Allocated CPU Count',
       :chargeback_rate_detail_measure_id => nil},
      {:metric => 'disk_usage_rate_average', :group => 'disk_io', :source => 'used', :description => 'Used Disk I/O',
       :chargeback_rate_detail_measure_id => measure_bps.id},
    ]
  end

  migration_context :up do
    it 'creates one field for each detail in default rate' do
      fields.each do |field|
        detail_stub.create!(field.merge(:chargeback_rate_id => default_rate.id))
        detail_stub.create!(field.merge(:chargeback_rate_id => custom_rate.id))
      end

      migrate

      created_fields = field_stub.all.collect(&:attributes).collect { |f| f.except('id').symbolize_keys }
      expect(created_fields).to match_array(fields)

      detail_stub.all.each do |d|
        expect(d.chargeable_field.metric).to eq(d.metric)
      end
    end
  end
end
