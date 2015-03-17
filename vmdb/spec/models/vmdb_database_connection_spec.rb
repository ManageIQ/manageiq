require "spec_helper"

describe VmdbDatabaseConnection do
  before :each do
    @db = FactoryGirl.create(:vmdb_database)
  end

  it 'can find connections' do
    connections = VmdbDatabaseConnection.all
    expect(connections.length).to be > 0
  end

  it 'computes wait_time' do
    setting = VmdbDatabaseConnection.all.first
    expect(setting.wait_time).to be_kind_of(Fixnum)
  end

  [
    :address,
    :application,
    :blocked_by,
    :command,
    :spid,
    :task_state,
    :wait_resource,
    :wait_time,
    :vmdb_database_id,
    :vmdb_database,
    :zone,
    :miq_server,
    :miq_worker,
    :pid,
  ].each do |field|
    it "has a #{field}" do
      setting = VmdbDatabaseConnection.all.first
      expect(setting).to respond_to(field)
    end
  end

  it 'returns nil for wait_resource where there are no locks' do
    continue = ActiveSupport::Concurrency::Latch.new
    made_connection = ActiveSupport::Concurrency::Latch.new

    get_connection = Thread.new do
      VmdbDatabaseConnection.connection.transaction do
        # make an empty txn to ensure we've sent something to the db
      end
      made_connection.release
      continue.await # block until the main thread has found this connection.
    end

    made_connection.await # wait until the thread has made a db connection

    connections = VmdbDatabaseConnection.all
    no_locks = connections.detect { |conn| conn.vmdb_database_locks.empty? }
    expect(no_locks).to be
    expect(no_locks.wait_resource).to be_nil

    continue.release
    get_connection.join
  end

  it 'is blocked' do
    locked_latch = ActiveSupport::Concurrency::Latch.new
    continue_latch = ActiveSupport::Concurrency::Latch.new

    get_lock = Thread.new do
      VmdbDatabaseConnection.connection.transaction do
        VmdbDatabaseConnection.connection.execute('LOCK users IN EXCLUSIVE MODE')
        locked_latch.release
        continue_latch.await
      end
    end

    wait_for_lock = Thread.new do
      VmdbDatabaseConnection.connection.transaction do
        locked_latch.await # wait until `get_lock` has the lock
        VmdbDatabaseConnection.connection.execute('LOCK users IN EXCLUSIVE MODE')
      end
    end

    locked_latch.await # wait until `get_lock` has the lock
    # spin until `wait_for_lock` is waiting to acquire the lock
    loop { break if wait_for_lock.status == "sleep" }

    connections = VmdbDatabaseConnection.all

    blocked_conn = connections.detect(&:blocked_by)
    expect(blocked_conn).to be
    blocked_by = connections.detect { |conn| conn.spid == blocked_conn.blocked_by }
    expect(blocked_by).to be
    expect(blocked_conn.spid).not_to eq(blocked_by.spid)

    continue_latch.release
    get_lock.join
    wait_for_lock.join
  end
end
