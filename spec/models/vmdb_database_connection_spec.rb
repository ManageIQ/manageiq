require "concurrent/atomic/event"

RSpec.describe VmdbDatabaseConnection do
  self.use_transactional_tests = false
  after :all do
    # HACK: Some other tests (around Automate) rely on the fact there's
    # only one connection in the pool. It's totally unfair to blame this
    # spec for using the API in a perfectly ordinary way.. but it solves
    # the immediate problem.
    VmdbDatabaseConnection.connection_pool.disconnect!
  end

  it 'can find connections' do
    connections = VmdbDatabaseConnection.all
    expect(connections.length).to be > 0
  end

  it 'returns nil for wait_resource where there are no locks' do
    continue = Concurrent::Event.new
    made_connection = Concurrent::Event.new

    get_connection = Thread.new do
      VmdbDatabaseConnection.connection.transaction do
        # make an empty txn to ensure we've sent something to the db
      end
      made_connection.set
      continue.wait # block until the main thread has found this connection.
    end

    made_connection.wait # wait until the thread has made a db connection

    connections = VmdbDatabaseConnection.all
    no_locks = connections.detect { |conn| conn.vmdb_database_locks.empty? }
    expect(no_locks).to be_truthy
    expect(no_locks.wait_resource).to be_nil

    continue.set
    get_connection.join
  end

  it 'is blocked' do
    VmdbDatabaseConnection.connection_pool.disconnect!
    locked_latch = Concurrent::Event.new
    continue_latch = Concurrent::Event.new
    wait_latch     = Concurrent::Event.new

    get_lock = Thread.new do
      VmdbDatabaseConnection.connection.transaction do
        VmdbDatabaseConnection.connection.execute('LOCK users IN EXCLUSIVE MODE')
        locked_latch.set
        continue_latch.wait
      end
    end

    wait_for_lock = Thread.new do
      VmdbDatabaseConnection.connection.transaction do
        wait_latch.set
        locked_latch.wait # wait until `get_lock` has the lock
        VmdbDatabaseConnection.connection.execute('LOCK users IN EXCLUSIVE MODE')
      end
    end

    locked_latch.wait # wait until `get_lock` has the lock
    wait_latch.wait   # spin until `wait_for_lock` is waiting to acquire the lock

    give_up = 10.seconds.from_now
    until (blocked_conn = VmdbDatabaseConnection.all.detect(&:blocked_by))
      if Time.current > give_up
        continue_latch.set
        get_lock.join
        wait_for_lock.join
        raise "Lock is not blocking"
      end
      sleep 1
    end

    blocked_by = VmdbDatabaseConnection.all.detect { |conn| conn.spid == blocked_conn.blocked_by }
    expect(blocked_by).to be_truthy
    expect(blocked_conn.spid).not_to eq(blocked_by.spid)

    continue_latch.set
    get_lock.join
    wait_for_lock.join
  end

  it 'computes wait_time' do
    setting = VmdbDatabaseConnection.all.first
    expect(setting.wait_time).to be_kind_of(Integer)
  end

  it 'wait_time_ms defaults to 0 on nil query_start' do
    conn = VmdbDatabaseConnection.first
    allow(conn).to receive_messages(:query_start => nil)
    expect(conn.wait_time_ms).to eq 0
  end

  [
    :address,
    :application,
    :blocked_by,
    :command,
    :spid,
    :wait_resource,
    :wait_time,
    :zone,
    :miq_server,
    :miq_worker,
    :pid
  ].each do |field|
    it "has a #{field}" do
      connection = VmdbDatabaseConnection.first
      expect { connection.public_send(field) }.not_to raise_error
    end
  end

  describe ".log_statistics" do
    before do
      @buffer = StringIO.new
      class << @buffer
        alias_method :info, :write
        alias_method :warn, :write
      end
    end

    it "normal" do
      described_class.log_statistics(@buffer)
      lines = @buffer.string.lines
      expect(lines.shift).to eq "MIQ(VmdbDatabaseConnection.log_statistics) <<-ACTIVITY_STATS_CSV\n"
      expect(lines.pop).to eq "ACTIVITY_STATS_CSV"

      header, *rows = CSV.parse lines.join
      expect(header).to eq %w(
        session_id
        xact_start
        last_request_start_time
        command
        login
        application
        request_id
        net_address
        host_name
        client_port
        wait_event_type
        wait_event
        wait_time_ms
        blocked_by
      )

      expect(rows.length).to be > 0
      rows.each do |row|
        expect(row.first).to be_truthy
      end
    end

    it "exception" do
      allow(described_class).to receive(:all).and_raise("FAILURE")
      described_class.log_statistics(@buffer)
      expect(@buffer.string.lines.first).to eq("MIQ(VmdbDatabaseConnection.log_statistics) Unable to log stats, 'FAILURE'")
    end
  end
end
