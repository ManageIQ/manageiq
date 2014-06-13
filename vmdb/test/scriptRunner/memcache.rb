# Requires vmdb.yml to be loaded with
#   session_store = cache
# and memcache_server pointed to a valid server configured for 64MB memory

require 'test/unit'

class MemcacheTest < ActiveSupport::TestCase

  LARGE_KEY = "large_value"
  LARGE_VALUE = "X" * 2.megabyte

  SMALL_KEY = "small_value"
  SMALL_VALUE = "XXX"

  # Value where after mashalling, the raw data size is exactly 1 MB
  ONE_MB_KEY = "one_mb"
  ONE_MB_VALUE = "X" * (1.megabyte - 7)

  # Value where after mashalling, the raw data size is exactly the chunking limit
  CHUNK_LIMIT_KEY = "chunk_limit"
  CHUNK_LIMIT_VALUE = "X" * (MemCache::LARGE_VALUE_SIZE - 7)

  # Value where after mashalling, the raw data size is exactly over the chunking limit
  CHUNK_LIMIT_PLUS_ONE_KEY = "chunk_limit_plus_one"
  CHUNK_LIMIT_PLUS_ONE_VALUE = "X" * (MemCache::LARGE_VALUE_SIZE - 6)

  def test_put_and_get
    [
      [LARGE_KEY, LARGE_VALUE],
      [SMALL_KEY, SMALL_VALUE],
      [ONE_MB_KEY, ONE_MB_VALUE],
      [CHUNK_LIMIT_KEY, CHUNK_LIMIT_VALUE],
      [CHUNK_LIMIT_PLUS_ONE_KEY, CHUNK_LIMIT_PLUS_ONE_VALUE],
    ].each do |k, v|

      ret = nil
      assert_nothing_raised(Exception) { ret = Cache.put(k, v) }
      assert_not_nil(ret)
      ret = nil
      assert_nothing_raised(Exception) { ret = Cache.get(k) }
      assert_equal(v, ret)
    end
  end

  def test_delete
    [
      [LARGE_KEY, LARGE_VALUE],
      [SMALL_KEY, SMALL_VALUE],
    ].each do |k, v|

      Cache.put(k, v)
      assert_nothing_raised(Exception) { Cache.delete(k) }
      assert_nil(Cache.get(k))
    end

  end

  def test_raw
    Cache.put(LARGE_KEY, LARGE_VALUE)

    ret = CACHE.get(LARGE_KEY, true)
    ret = Marshal.load(ret)
    assert_equal(MemCache::LARGE_VALUE_KEY, ret[0..MemCache::LARGE_VALUE_KEY.length - 1])
  end

  def test_overfill_cache
    50.times { |x| Cache.put("#{LARGE_KEY}_#{x}", LARGE_VALUE) }
    assert_nil(Cache.get("#{LARGE_KEY}_1"))
    assert_not_nil(Cache.get("#{LARGE_KEY}_49"))
  end

  def test_boundaries
    v = CHUNK_LIMIT_VALUE[0..-5]

    10.times do |x|
      k = "bound_#{x}"
      v += "X"

      ret = nil
      assert_nothing_raised(Exception) { ret = Cache.put(k, v) }
      assert_not_nil(ret)
      ret = nil
      assert_nothing_raised(Exception) { ret = Cache.get(k) }
      assert_equal(v, ret)
    end
  end
end
