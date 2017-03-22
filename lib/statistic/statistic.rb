module Statistic

  # The factory class is a helper class to create and reuse statistical data from objects
  # Main core is an array of ordered objects with key-value pairs in a hash. 
  # This array will be generated by complementary search methods.
  # The to_* classes return objects for partial views.
  # The to_chart and to_pie method builds objects ready to use in chart.js
  # The to_table object return an array of rows, where the first is the header. It can be used in ActiveAdmin table_for 
  class Factory

    class Item
      attr_accessor :object, :row
      def initialize(object, row)
        @object=object
        @row=row
      end
    end

    attr_accessor :header, :objects

    # This initialzer needs the ItemFactory
    def initialize(items)
      @objects = []
      items.each do |k,v| 
        @objects << Item.new(k,v)
      end
      @header = @objects.first.row.keys
    end

    #This method adds more columns to items
    #It is configured b< the options hash
    # - :attributes => an array object.attributes (e.g. :name)
    # - :summarize => appends a column sith the summarized values of the row
    def with_attributes(options={})
      attributes = options[:attributes] || []
      summarize = options[:summarize]
      existent = Marshal.load(Marshal.dump(self))
      attributes.reverse.each { |att| existent.header.unshift(att) } unless attributes.empty?
      existent.header << "SUM" if summarize
      existent.objects.each do |item|
        line = ActiveSupport::OrderedHash.new
        attributes.each do |att|
          line[att] = item.object.send(att)
        end
        item.row.each do |k,v|
          line[k] = v
        end
        if summarize
          total = 0
          item.row.values.each {|v| total += v if v.is_a?(Integer)}
          line['SUM'] = total
        end

        item.row = line
      end
      return existent
    end

    def to_table(options={})
      res = []
      existent = with_attributes(options)
      res << existent.header
      existent.objects.each do |item|
        res << item.row.values
      end
      return res
    end

    def to_pie(attribute, options={:limit => -1})
      res = Hash.new(0)
      res2 = {}
      objects.each do |item|
        res[item.object.send(attribute)] += item.row.values.sum
      end
      res.sort_by(&:last).reverse[0..options[:limit]].each do |e|
        res2[e[0]] = e[1]
      end
      return res2
    end

    def to_chart
      res = Hash.new(0)
      objects.each do |item|
        header.each do |index|
          res[index] += item.row[index]
        end
      end
      return res
    end

  end
end
