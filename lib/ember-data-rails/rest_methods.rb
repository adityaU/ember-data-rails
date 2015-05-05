require 'json'
require 'will_paginate'
require_relative './serializer'
module EmberDataRailsHelper
  include EmberDataSerializer
  # def selfV.included klass
  #   klass.instance_eval do
  #     include ::WillPaginate
  #   end
  #
  # end

  def camelize_keys(value)
    case value
    when Array
      value.map { |v| camelize_keys(v) }
    when Hash
      Hash[value.map { |k, v| [k.to_s.camelize(:lower), (!@modelClass.nil? and  @modelClass.not_camelizable.include?(k.to_sym)) ? v : camelize_keys(v)] }]
    else
      value
    end
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

  def index
    # handles /:resources kind of request
    # returns json with all the camilized keys
    # including relationships, just as
    # ember-data wants it.
    resource_name = params["controller"]
    unless @model
      model = class_eval(resource_name.singularize.camelize)
      @model = model
    else
      model = @model.model
    end
    @modelClass = @model
    _where = where_hash(model)
    _order = order_hash(model)
    resource = @model.where(_where).preload(model.reflections.keys).order(_order)
    resource = params[:all] ? resource : resource.paginate(per_page: params[:per_page], page: params[:page])
    render :json => { resource_name.camelize(:lower) => camelize_keys(ember_serialize(resource))}
  end


  def show
    # handles :resource/:id kinda Get request.
    # returns json  with all the camilized keys
    # including relationships, just as
    # ember-data wants it.
    resource_name = params["controller"]
    unless @model
      model = class_eval(resource_name.singularize.camelize)
      @model = model
    else
      model = @model.model
    end
    @modelClass = @model
    _where = where_hash(model)
    resource = model.where(_where).preload(model.reflections.keys).find(params[:id])
    render :json => {resource_name.singularize => camelize_keys(ember_serialize(resource))}
  end


  def update
    # handles :resource/:id kinda PUT request.
    # updates the record and then
    # returns record json  with all the camilized keys
    # including relationships, just as
    # ember-data wants it.
    resource_name = params["controller"]
    unless @model
      model = class_eval(resource_name.singularize.camelize)
    else
      model = @model
    end
    @model = model.find_by_id(params[:id].to_i)
    obj = params[model.to_s.camelize(:lower)]
    @model = save_model(model, @model, obj)
    @modelClass = @model.class
    render json:  {resource_name.singularize => camelize_keys(ember_serialize(@model))}
  end

  def create
    # handles :resource kinda POST request.
    # creates a new record and then
    # returns record json  with all the camilized keys
    # including relationships, just as
    # ember-data wants it.
    resource_name = params["controller"]
    unless @model
      model = class_eval(resource_name.singularize.camelize)
    else
      model= @model
    end
    @model = model.new
    obj = params[model.to_s.camelize(:lower)]
    @model = save_model(model, @model, obj)
    @modelClass = @model.class
    render json:  {resource_name.singularize => camelize_keys(ember_serialize(@model))}
  end

  def destroy
    resource_name = params["controller"]
    unless @model
      model = class_eval(resource_name.singularize.camelize)
    else
      model=@model
    end
    record = model.find_by_id(params[:id].to_i)
    model.delete(record)
    @modelClass = @model.class
    render json:  {resource_name.singularize => camelize_keys(ember_serialize(record))}
  end

  def permit_params model
    @model.require(resource_name.singularize.to_sym).permit(attribute_names)
  end
end
