module ActsAsSplittable

  module Splittable

    def split_column_values!(column = nil)
      if column.nil?
        self.class.splittable_columns.each_key{|key| send __method__, key }
      else
        column                                      = column.to_sym
        split, pattern, partials, on_split, on_join = self.class.splittable_columns[column]
        value                                       = send(column)

        unless value.nil?
          values = if on_split
            splittable_run_callback(on_split, value)
          elsif value
            if split
              value.to_s.split *(split.is_a?(Array) ? split : [split])
            elsif matches = value.to_s.match(pattern)
              matches[1..(matches.length - 1)]
            end
          end || []

          partials.each_with_index do |partial, index|
            send :"#{partial}=", values[index]
          end

          reset_splittable_changed_partials partials
        end
      end

      self
    end

    def join_column_values!(column = nil)
      if column.nil?
        self.class.splittable_columns.each_key{|key| send __method__, key }
      else
        split, pattern, partials, on_split, on_join = self.class.splittable_columns[column.to_sym]
        values                                      = partials.map{|partial| send(partial) }

        unless values.any?(&:nil?)
          send :"#{column}=", splittable_run_callback(on_join, values)
          reset_splittable_changed_partials partials
        end
      end

      self
    end

    def splittable_partials
      @splittable_partials ||= {}
    end

    protected

    attr_writer :splittable_changed_partials

    def splittable_changed_partials
      @splittable_changed_partials ||= []
    end

    def splittable_changed_partial?(partial)
      splittable_changed_partials.include? partial
    end

    def reset_splittable_changed_partials(partials)
      self.splittable_changed_partials.uniq!
      self.splittable_changed_partials -= partials
    end

    private

    def splittable_run_callback(callback, *args)
      if callback.is_a?(Proc)
        instance_exec(*args, &callback)
      else
        send(callback, *args)
      end
    end
    
  end

end