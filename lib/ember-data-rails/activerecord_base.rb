class ActiveRecord::Base

  class << self
    alias_method :orig_has_one, :has_one
    def has_one(*args)
      define_method((args[0].to_s + '_id').to_sym) do
        self.send(args[0]).id if self.send(args[0])
      end
      orig_has_one(*args)
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
      self.attribute_names_old + self.extra_attributes.map(&:to_s) - self.hidden_attributes.map(&:to_s)
    end
  end

  alias :attributes_old :attributes
  def attributes
    self.class.extra_attributes = [] if self.class.extra_attributes.nil?
    attrs = self.class.extra_attributes.inject(self.attributes_old) {|r, k| r.merge!({k.to_s => self.send(k)}) }
    attrs.except!(*self.class.hidden_attributes.map(&:to_s)) if !self.class.hidden_attributes.nil?
    attrs
  end
end
