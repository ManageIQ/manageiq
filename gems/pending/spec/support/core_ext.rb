class Class
  def test_new(*params, &block)
    o = allocate
    yield(o) if block
    o.__send__(:initialize, *params)
    return o
  end
end
