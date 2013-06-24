module ActsAsSplittable
  class Splitter < Struct.new(:name, :for_split, :pattern, :partials, :on_split, :on_join)
    DEFAULTS = {
      on_join: Proc.new {|values| values.join }
    }.freeze

    ALIASES = {
      split:  :for_split,
      column: :name,
      regex:  :pattern,
    }.freeze

    def initialize(options = {})
      @options = DEFAULTS.merge(options)
      @options.each do |key, value|
        case key
        when *ALIASES.keys
          self[ALIASES[key]] = value
        else
          self[key] = value
        end
      end
      self.partials ||= pattern_members
    end

    def split(value, delegate = nil)
      case
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
  end
end
