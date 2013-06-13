require 'active_record'

module ActsAsSplittable

  def acts_as_splittable(options = {})
    options.reverse_merge!(
      callbacks: true,
    )

    extend  ClassMethods
    include InstanceMethods

    if options[:callbacks]
      after_initialize { new_record? or split_column_values! }
      before_save      { join_column_values! }
    end
  end

  module ClassMethods
    SPLITTABLE_DEFAULT_JOIN_PROCESS = Proc.new{|values| values.join }

    def splittable_columns
      @splittable_columns ||= {}
    end

    def splittable(column, options)
      column                     = column.to_sym
      partials                   = (options[:partials] || options[:pattern].names).map(&:to_sym)
      splittable_columns[column] = [options[:split], options[:pattern], partials, options[:on_split], options[:on_join] || SPLITTABLE_DEFAULT_JOIN_PROCESS]

      partials.each do |partial|
        define_method partial do
          splittable_partials[partial]
        end

        define_method :"#{partial}=" do |value|
          splittable_partials[partial] = value
        end
      end
    end

    def inherited(child)
      super
      child.splittable_columns.merge! splittable_columns.dup
    end
  end

  module InstanceMethods
    def split_column_values!(column = nil)
      if column.nil?
        self.class.splittable_columns.each_key{|key| send __method__, key }
      else
        column                                      = column.to_sym
        split, pattern, partials, on_split, on_join = self.class.splittable_columns[column]
        value                                       = send(column)

        values = if on_split
          on_split.is_a?(Symbol) ? send(on_split, value) : on_split.(value)
        elsif value
          if split
            value.to_s.split *(split.is_a?(Array) ? split : [split])
          else
            matches = value.to_s.match(pattern)
            matches[1..(matches.length - 1)]
          end
        end || []

        partials.each_with_index do |partial, index|
          send :"#{partial}=", values[index]
        end
      end

      self
    end

    def join_column_values!(column = nil)
      if column.nil?
        self.class.splittable_columns.each_key{|key| send __method__, key }
      else
        split, pattern, partials, on_split, on_join = self.class.splittable_columns[column.to_sym]
        partials                                    = partials.map{|partial| send(partial) }

        send :"#{column}=", on_join.is_a?(Symbol) ? send(on_join, partials) : on_join.(partials)
      end
        
      self
    end

    def splittable_partials
      @splittable_partials ||= {}
    end
  end
end

ActiveRecord::Base.extend ActsAsSplittable