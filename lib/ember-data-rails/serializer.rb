module EmberDataSerializer
	def relationships(model_class)
    model_class.reflections.inject({}) do |result, ref|
			case ref[1].macro
			when :has_many
			  result.merge!({ref[1].name => (ref[1].name.to_s.singularize + '_ids').to_sym})
			when :has_one , :belongs_to
			  result.merge!({ref[1].name => (ref[1].name.to_s + '_id').to_sym})
			else
				result
			end

		end
	end

	def ember_serialize(resource)
		if resource.respond_to?(:model)
			resource.map {|r| ember_serialize(r)}
		else
			model_relationships = relationships(resource.class)
			model_relationships.inject(resource.attributes) do |r, k|
				r.merge!({k.first.to_sym => resource.send(k.last)})
			end
		end
	end
end
