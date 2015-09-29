require_relative './activerecord_base'

module EmberDataRailsHelper
  module EmberDataHelpingMethods
    def cache_key
      unless @cache_key
        request.fullpath
      else
        @cache_key
      end
    end
    def cache_expiration_time
      if @cache_expiration_time
        @cache_expiration_time
      else
        3.hours
      end
    end
    def camelize_keys(value)
      if @camelize_all_keys
        case value
        when Array
          value.map { |v| camelize_keys(v) }
        when Hash
          Hash[value.map { |k, v| [k.to_s.camelize(:lower), (!@modelClass.nil? and  @modelClass.not_camelizable.include?(k.to_sym)) ? v : camelize_keys(v)] }]
        else
          value
        end
      else
        value
      end
    end

    def sideload_relationship jsonHash
      if @sideload_relationships
        slr = @sideload_relationship.dup
        for k, v in  slr do
          if jsonHash[v[1].to_s.pluralize.camelize(:lower)] 
            v[0] -=  jsonHash[v[1].to_s.pluralize.camelize(:lower)].map{|item| item['id']} 
            jsonHash[v[1].to_s.pluralize.camelize(:lower)] += camelize_keys(ember_serialize(v[1].where(id: v[0].to_a)))
          else
            jsonHash[v[1].to_s.pluralize.camelize:lower] = camelize_keys(ember_serialize(v[1].where(id: v[0].to_a)))
          end
        end
      end
      jsonHash
    end

    def save_model(modelClass,modelObj, obj)
      # handles relationships as well.
      # may have problems saving has_many
      # through polymorphic relationships
      additional_keys = relationships(modelClass)
      obj.each do |key, value|
        key = key.underscore
        if modelClass.attribute_names.include? key
          modelObj.send(key + '=', value)
        elsif additional_keys.keys.map(&:to_s).include? key
          if !modelClass.ignore_update_for.include?(key.to_sym)
            modelObj.send(additional_keys[key.to_sym].to_s + '=', value)
          end
        end
      end
      modelObj.save
      modelObj
    end


    def where_hash(model)
      # generates a where hash according to the request.
      # so :resources?key='string' like
      # requests are possible. Valid on relationships as well.
      where = {}
      model.attribute_names.each do |attr|
        key = params[attr.to_sym] || params[attr.pluralize.to_sym]
        where[attr] = key if key
      end
      model.reflections.each do |association|
        if association[1].macro == :has_many
          key = association[0].to_s.singularize + '_ids'
          if params[key]
            if association[1].class.to_s.match(/AssociationReflection/)
              klass = association[1].name.to_s.camelize.singularize
              where[:id] = class_eval(klass).where(id: JSON.parse(params[key])).map{|i| i[(model.to_s.downcase.singularize + '_id').to_sym]}
            elsif association[1].class.to_s.match(/ThroughReflection/)
              klass = association[1].options[:through].to_s.camelize.singularize
              where[:id] = class_eval(klass).where(key.singularize.to_sym => JSON.parse(params[key])).map{|i| i[(model.to_s.downcase.singularize + '_id').to_sym]}
            end
          end
        elsif [:has_one].include?(association[1].macro)
          key = association[0].to_s.singularize + '_id'
          parameters = params[key] || params[key.pluralize]
          if parameters
            if association[1].class.to_s.match(/AssociationReflection/)
              klass = association[1].name.to_s.camelize.singularize
              where[:id] = class_eval(klass).where(id: parameters).map{|i| i[(model.to_s.downcase.singularize + '_id').to_sym]}
            end
          end
        end

      end
      where

    end

    def order_hash(model)
      # generates a order hash according to the request
      # so :resources?sort_by=['key', 'asc/desc'] like
      # requests are possible
      _order = {}
      model.attribute_names.each do |attr|
        if params['sort_by']
          order = params['sort_by']
          _order[order[0].to_sym] = order[1].to_sym if order[0] == attr
        end
      end
      _order.empty? ? {id: :asc} : _order
    end

    def to_be_loaded_relationships model
      model.reflections.keys - model.instance_variable_get(:@hidden_attributes)
    end

  end
end
