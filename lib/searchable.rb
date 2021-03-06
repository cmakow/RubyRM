require_relative 'db_connection'
require_relative 'sql_object'

module Searchable
  def where(params)
    values = params.values
    if is_relation?(self)
      self.values.each do |value|
        values.push(value)
      end
    end
    cols = params.keys.map { |key| "#{key} = ?" }
    where_string = cols.join(" AND ")
    if is_relation?(self)
      where_string = [where_string, self.where_string].join(" AND ")
    end

    heredoc = <<-SQL
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{where_string}
    SQL

    result = DBConnection.execute(heredoc, *values)

    class_name = get_class_name(self)

    Relation.new(result.map{ |attrs| class_name.new(attrs) }, where_string, values)
  end

  private
  # checks if we are calling on a relation or not, fetches correct classname if it is relation
  def get_class_name(object)
    if object.class.to_s == 'Relation'
      return object.collection[0].class
    else
      return object
    end
  end

  def is_relation?(object)
    if object.class.to_s == 'Relation'
      return true
    else
      return false
    end
  end
end

class SQLObject extend Searchable
end

# takes in an array of model objects and extends searchable to allow where to be called on them
class Relation include Searchable
  include Enumerable
  attr_reader :table_name, :collection, :where_string, :values

  def initialize(model_objects, where_string = nil, values = nil)
    @collection = model_objects
    if @collection[0]
      @table_name = @collection[0].class.table_name
    end
    @where_string = where_string
    @values = values
  end

  def [](index)
    @collection[index]
  end

  def first
    @collection[0]
  end

  def each(&prc)
    @collection.length.times do |i|
      prc.call(@collection[i])
    end

    @collection
  end
end
