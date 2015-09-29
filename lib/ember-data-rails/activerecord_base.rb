require_relative './cache_store'
require_relative './default_configuration'
class ActiveRecord::Base

  class << self
    alias_method :orig_has_one, :has_one
    def has_one(*args, **kwargs)
      define_method((args[0].to_s + '_id').to_sym) do
        self.send(args[0]).id if self.send(args[0])
      end
      orig_has_one(*args, **kwargs, &block)
    end

    alias_method :orig_belongs_to, :belongs_to
    def belongs_to(*args, **kwargs, &block )
      kwargs[:touch] = true
      orig_belongs_to(*args, **kwargs, &block)
    end

    attr_accessor :extra_attributes, :hidden_attributes, :not_camelizable
    def add_extra_attributes(*args)
      @extra_attributes = [*args]
      args.each {|arg| define_method(arg.to_s + '='){|values|}}
    end
    def do_not_camelize(*args)
      @do_not_camelize = [*args]
    end

    def do_not_update(*args)
      @do_not_update = [*args]
    end

    def ignore_update_for
      @do_not_update =  @do_not_update.nil? ? [] : @do_not_update
    end

    def not_camelizable
      @do_not_camelize = @do_not_camelize.nil? ? [] : @do_not_camelize
    end

    def hide_attributes(*args)
      @hidden_attributes = [*args]
    end

    alias :attribute_names_old :attribute_names
    def attribute_names
      self.extra_attributes = [] if self.extra_attributes.nil?
      self.hidden_attributes = [] if self.hidden_attributes.nil?
      self.attribute_names_old + self.extra_attributes.map(&:to_s)  - self.hidden_attributes.map(&:to_s)
    end
  end

  attr_accessor :cache_key
  def all_attributes
    @cache_key = @cache_key || "#{self.class.to_s}/#{self.id}-#{self.updated_at}"
    @cache_expiration_time = @cache_expiration_time || nil
    @cache_store =  EmberDataRailsHelper::Caching::MemoryCache.instance

    self.class.attribute_names.inject({}) {|r, k| 
      value  = EmberDataRailsHelper::Defaults.disable_model_cache ? self.send(k) : @cache_store.fetch("#{@cache_key}/#{k.to_s}", expires_in: @cache_expiration_time) {self.send(k)} 
      r.merge!({k.to_s => value})
    }
  end
  
end
