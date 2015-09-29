require_relative './activerecord_base'

module EmberDataRailsHelper
  module EmberDataSerializer
    def relationships(model_class)
      model_class.reflections.inject({}) do |result, ref|
        unless (model_class.instance_variable_get(:@hidden_attributes)|| []).include?(ref[1].name.to_sym)
          case ref[1].macro
          when :has_many
            result.merge!({ref[1].name => [(ref[1].name.to_s.singularize + '_ids').to_sym,ref[1].instance_variable_get(:@klass) ]})
          when :has_one , :belongs_to
            result.merge!({ref[1].name => [(ref[1].name.to_s + '_id').to_sym,ref[1].instance_variable_get(:@klass)]})
          else
            result
          end
        else
          result
        end
      end.compact
    end

    def sideloaded_ids k, value
      @sideload_relationship[k.first.to_sym] ||= [Set.new, k.last[1]]
      if value.is_a?(Array)
        @sideload_relationship[k.first.to_sym][0] += value.to_set
      else
        @sideload_relationship[k.first.to_sym][0] << value
      end
    end

    def ember_serialize(resource)
      @sideload_relationship ||= {}
      if resource.respond_to?(:model)
        resource.map {|r| ember_serialize(r)}
      else
        relationships(resource.class).inject(resource.all_attributes) {|r, k|
          value =  resource.send(k.last[0])
          sideloaded_ids k, value if @sideload_relationships
          r.merge!({k.first.to_sym => value })
        }
      end
    end
  end
end
