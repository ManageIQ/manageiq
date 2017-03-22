require_migration

describe RemoveOidIntegerArgsFromMiqQueue do
  let(:queue_stub) { migration_stub(:MiqQueue) }

  migration_context :up do
    it 'deletes rows with PostgreSQL::OID:Integer class serialized in args' do
      args = <<-EOS
---
- !ruby/object:ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Integer
    precision:
    scale:
    limit: 8
    range: !ruby/range
      begin: -9223372036854775808
      end: 9223372036854775808
      excl: true
EOS
      queue_stub.create(:state => "ready", :args => args)
      queue_stub.create(:state => "ready", :method_name => "stuff")
      migrate

      expect(queue_stub.count).to eq(1)
      expect(queue_stub.where(:method_name => "stuff").count).to eq(1)
    end
  end
end
