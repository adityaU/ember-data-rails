require 'json'
require 'will_paginate'
require_relative './serializer'
require_relative './helping_methods'
require_relative './default_configuration'
module EmberDataRailsHelper
  include EmberDataSerializer
  include EmberDataHelpingMethods
  include Defaults


  def index
    # handles /:resources kind of request
    # returns json with all the camilized keys
    # including relationships, just as
    # ember-data wants it.
    #
    unless @disable_action_cache
      jsonHash = Rails.cache.fetch("#{cache_key}", expires_in: cache_expiration_time) do 
        index_model
      end
    else
      jsonHash = index_model
    end
    if @directly_render; (render layout: false, json: jsonHash); else jsonHash; end
  end



  def show
    # handles :resource/:id kinda Get request.
    # returns json  with all the camilized keys
    # including relationships, just as
    # ember-data wants it.
    #
    unless @disable_action_cache
      jsonHash = Rails.cache.fetch("#{cache_key}", expires_in: cache_expiration_time) do 
        show_model
      end
    else
      jsonHash = show_model
    end
    if @directly_render; (render layout: false, json: jsonHash); else return jsonHash; end
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
    jasonHash = sideload_relationship({resource_name.singularize => camelize_keys(ember_serialize(@model))})
    if @directly_render; (render layout: false, json: jsonHash); else return jsonHash; end
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
    jsonHash =   sideload_relationship({resource_name.singularize => camelize_keys(ember_serialize(@model))})
    if @directly_render; (render layout: false, json: jsonHash); else return jsonHash; end
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
    jsonHash = sideload_relationship({resource_name.singularize => camelize_keys(ember_serialize(record))})
    if @directly_render; (render layout: false, json: jsonHash); else return jsonHash; end
  end


  private
  def index_model
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

      resource = @model.where(_where).eager_load(to_be_loaded_relationships(@model)).order(_order)
      total_pages = (resource.count.to_i/ (params[:per_page]? params[:per_page].to_i : 30)) + 1
      resource = params[:all] ? resource : resource.paginate(per_page: params[:per_page], page: params[:page])
      jsonHash = sideload_relationship ({ model.to_s.pluralize.camelize(:lower) => camelize_keys(ember_serialize(resource)), 'meta' => {total_pages: total_pages}})
  end


  def show_model
      resource_name = params["controller"]
      unless @model
        model = class_eval(resource_name.singularize.camelize)
        @model = model
      else
        model = @model.model
      end
      @modelClass = @model
      _where = where_hash(model)
      resource = model.where(_where).eager_load(to_be_loaded_relationships model).find(params[:id])
      jsonHash = sideload_relationship({resource_name.singularize => camelize_keys(ember_serialize(resource))})
  end

  def permit_params model
    @model.require(resource_name.singularize.to_sym).permit(attribute_names)
  end
end
