require 'yaml'
require_relative './cache_store'
module EmberDataRailsHelper

  module Defaults
      class<< self
        attr_accessor :disable_model_cache
      end
      def initialize(*args, **kwargs, &block)
        conf = {}
        begin
          conf = YAML.load_file(Rails.root.join('config/ember_data_rails_helper.yml').to_s)
        rescue
          puts 'easy_api.yml not found in config folder.'
        end

        @directly_render = (conf['directly_render'] == false) ? false : true
        @camelize_all_keys = (conf['camelize_all_keys'] == false) ? false :  true
        @sideload_relationships =  (conf['sideload_relationships'] == false) ? false :  true
        @disable_action_cache = conf['disable_action_cache'] || false
        EmberDataRailsHelper::Defaults.disable_model_cache = conf['disable_model_cache'] || false
        EmberDataRailsHelper::Caching::MemoryCache.size =  conf['memory_cache_maxsize'] || 64.megabytes
        super()
      end

  end
end
