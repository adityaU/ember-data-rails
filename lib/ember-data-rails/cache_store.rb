module EmberDataRailsHelper
  module Caching
    class MemoryCache
      include Singleton
      class <<self
        attr_accessor :size
      end
      # create a private instance of MemoryStore
      def initialize
        @memory_store = ActiveSupport::Cache::MemoryStore.new({size: self.class.size})
      end

      # this will allow our MemoryCache to be called just like Rails.cache
      # every method passed to it will be passed to our MemoryStore
      def method_missing(m, *args, &block)
        @memory_store.send(m, *args, &block)
      end
    end
  end
end
