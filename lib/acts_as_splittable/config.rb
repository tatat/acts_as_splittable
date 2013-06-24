module ActsAsSplittable
  class Config
    def splitters
      @splitters ||= []
    end

    def splitter(key)
      splitters.find do |splitter|
        splitter.name == key.to_sym
      end
    end

    def inherit!(other)
      splitters.replace (other.splitters + splitters).uniq(&:name)
    end
  end
end
