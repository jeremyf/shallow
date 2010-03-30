require 'yaml'
require 'singleton'
module Shallow
  CACHE_FOLDER = 'shallow'
  module Method
    def self.with_cache_clearing_for(context)
      yield and return unless context.respond_to?(:returning_value_cache_caller)
      old_method = context.method(:returning_value_cache_caller)
      context.meta_def(:returning_value_cache_caller) do
        Shallow::Caller::Clear
      end
      yield
    ensure
      context.meta_def(:returning_value_cache_caller, &old_method)
    end

    def shallow_method(method_name, options = {})
      scope = options[:scope] || options['scope'] || lambda { nil }
      class_eval do
        define_method(:returning_value_cache_caller) do
          Shallow::Caller::Base
        end
        old_method = instance_method(method_name.to_sym)
        define_method(method_name.to_sym) do |*args, &block|
          returning_value_cache_caller.new(
          :args => args,
          :keys => [instance_eval(&scope).to_s, method_name],
          :capture => old_method.bind(self)
          ).call(&block)
        end
      end
    end
  end
  class Cache
    def initialize
      @cache = {}
    end
    include Singleton
    def exist?(key)
      @cache.key?(key)
    end
    def fetch(key)
      if @cache.key?(key)
        @cache.fetch(key)
      else
        @cache[key] = yield
      end
    end
    def delete(key)
      @cache.delete(key)
    end
    def read(key)
      @cache.fetch(key)
    end
  end

  module Caller
    class Base
      attr_reader :cache_key, :captured_method
      def initialize(options = {})
        keys = options[:keys]
        @args = options[:args]
        @cache_key = File.join(keys.inject([CACHE_FOLDER]){|m,v| m << v.to_s})
        @captured_method = options[:capture]
      end

      def call(&context)
        if cache.exist?(cache_key)
          returning_value = YAML.load(cache.read(cache_key))
          context.call(*returning_value, &context) if block_given? && !returning_value.nil?
          return *returning_value
        else
          returning_value = nil
          cache.fetch(cache_key) {
            returning_value = captured_method.call(*@args, &lambda {|args| context.call(args); args })
            returning_value ? [returning_value].to_yaml : nil.to_yaml
          }
          return *returning_value
        end
      end
      protected
      def cache
        Cache.instance
      end
    end
    class Clear < Base
      def call(&context)
        cache.delete(cache_key) if cache.exist?(cache_key)
        super(&context)
      end
    end
  end
end