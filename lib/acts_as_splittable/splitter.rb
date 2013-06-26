module ActsAsSplittable
  class Splitter < Struct.new(:name, :for_split, :pattern, :attributes, :on_split, :on_join, :type)
    DEFAULTS = {
      on_join: Proc.new {|values| values.join }
    }.freeze

    ALIASES = {
      split:    :for_split,
      column:   :name,
      regex:    :pattern,
      partials: :attributes,
    }.freeze

    def initialize(options = {})
      @options = options

      options   = DEFAULTS.merge(options)
      delimiter = options.delete(:delimiter)

      options.each do |key, value|
        case key
        when *ALIASES.keys
          self[ALIASES[key]] = value
        else
          self[key] = value
        end
      end

      if delimiter
        self.for_split = [delimiter]
        self.on_join   = Proc.new {|values| values.join(delimiter)}
      end

      self.attributes ||= pattern_members
    end

    def split(value, delegate = nil)
      cast case
      when on_split
        delegation(delegate || self, on_split, value)
      when for_split
        value.to_s.split *Array(for_split)
      when pattern
        value.to_s.match(pattern).to_a.tap(&:shift)
      else
        Array(value)
      end
    end

    def restore(values, delegate = nil)
      delegation(delegate || self, on_join, values)
    end

    private
    def delegation(target, method, *args)
      if method.is_a?(Proc)
        target.instance_exec(*args, &method)
      else
        target.__send__(method, *args)
      end
    end

    def pattern_members
      pattern.names.map(&:to_sym)
    end

    def cast(values)
      case type
      when Proc, Symbol
        values.map(&type)
      when Class
        name = type.name.to_sym
        
        values.map{|value| Object.__send__(name, value) } if
          Object.private_method_defined?(name)
      end || values
    end
  end
end
