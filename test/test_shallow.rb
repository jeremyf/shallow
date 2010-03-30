require 'helper'

class TestShallow < Test::Unit::TestCase
  def setup
    @klass = Class.new {
      attr_accessor :value
      extend Shallow::Method
      def foo(msg)
        msg
      end
      shallow_method(:foo)
      def bar(*args)
        yield(*args)
      end
      shallow_method(:bar)

      def with_value
        return nil if value.nil?
        yield(value)
      end
      shallow_method(:with_value)
    }
    @object = @klass.new
  end
  
  def test_cache_return_value
    assert_equal 'message', @object.foo('message')
    assert_equal 'message', @object.foo('bob_message')
  end
  
  def test_cache_yielded_values
    @yielded_value = nil
    @object.bar(1,2,3) { |a,b,c| @yielded_value = [a,b,c] }
    assert_equal [1,2,3], @yielded_value
    @object.bar(2,3,4) { |a,b,c| @yielded_value = [a,b,c] }
    assert_equal [1,2,3], @yielded_value
  end
  
  def test_cache_return_value_and_yield_value
    @yielded_value = :false
    @object.value = nil
    assert_equal nil, @object.with_value { |val| @yielded_value = val }
    assert_equal :false, @yielded_value

    @object.value = 1
    assert_equal nil, @object.with_value { |val| @yielded_value = val }
    assert_equal :false, @yielded_value
  end
end
