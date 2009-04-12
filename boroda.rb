module Boroda
  
  def self.build(&block)
    return Builder.new(&block).sql
  end 
  
  class Builder
  
    def initialize(&block)
      @sql_parts = {}
      @tables = {}
      @columns = []    
      
      build(&block) if block_given?
    end
   
    def build(&block)
      instance_eval &block
      return sql
    end  
     
    def sql
      processed_parts = []
      processed_parts << "SELECT *" if !@sql_parts.has_key? :select
      [:select, :from, :join, :where, :group, :having, :order, :limit, :offset].each do |key|
        if !@sql_parts.has_key? key
          next 
        elsif key == :join
          processed_parts << @sql_parts[key].join("\n")
        else
          processed_parts << @sql_parts[key]
        end    
      end
      
      return processed_parts.join("\n")
    end
    
    def to_s
      return sql
    end
       
    def make_table_list(tables)
      tables_processed = []
      tables.each do |element|

        if element.is_a?(Hash)
          element.each do |real_name, pseudonym|
            add_table(real_name, pseudonym)
            tables_processed << "#{real_name} AS #{pseudonym}"
          end
        else
          add_table(element, element)
          tables_processed << element.to_s
        end
      end
      return tables_processed.join(", ")    
    end
    
    def make_column_list(columns) 
      columns_processed = []
      columns.each do |element|
        if element.is_a?(Hash)
          element.each do |real_name, pseudonym|
            add_column(pseudonym)
            columns_processed << "#{real_name} AS #{pseudonym}"
          end
        else
          add_column(element) if element.is_a? Symbol
          columns_processed << element.to_s
        end
      end
       
      return columns_processed.join(", ")
    end    
   
    def select(*fields)
      @sql_parts[:select] = "SELECT " + make_column_list(fields)
    end
    
    def from(*tables)
      @sql_parts[:from] = "FROM " + make_table_list(tables) 
    end
    
    def join(*tables) 
      @sql_parts[:join] = [] if !@sql_parts.has_key? :join
      @sql_parts[:join] << "JOIN " + make_table_list(tables)
      return @sql_parts[:join].last
    end
    
    def left(join_statement)
      join_statement.replace "LEFT " + join_statement
    end

    def right(join_statement)
      join_statement.replace "RIGHT " + join_statement
    end

    def inner(join_statement)
      join_statement.replace "INNER " + join_statement
    end
    
    def outer(join_statement)
      join_statement.replace "OUTER " + join_statement
    end  

    def cross(join_statement)
      join_statement.replace "CROSS " + join_statement
    end 
    
    def on(clause)
      @sql_parts[:join] << "ON " + clause.to_s
    end    

    def using(columns)
      @sql_parts[:join] << "USING (" + make_column_list(columns) + ")"
    end  
 
    
    def where(clause)
      @sql_parts[:where] = "WHERE " + clause.to_s
    end   
    
    def having(clause)
      @sql_parts[:having] = "HAVING " + clause.to_s
    end     
    
    
    def limit(number)
      @sql_parts[:limit] = "LIMIT #{number.to_i}"
    end
    
    def offset(number)
      @sql_parts[:offset] = "OFFSET #{number.to_i}"
    end
        
    def order(*fields)
      @sql_parts[:order] = "ORDER BY " + make_column_list(fields)
    end   
    
    def group(*fields)
      @sql_parts[:group] = "GROUP BY " + make_column_list(fields)
    end   

    # Used for ORDER BY and GROUP BY
    def by(*fields)
      return fields
    end    
    
    def desc(field)
      return expression "#{field} DESC"
    end   
    
    def all
      return expression "*"
    end  

    def col(column)
      return expression column.to_s
    end 

    # Method alllow to write sql function calls
    # Example: func(:concat, user.last_name, ', ', user.first_name) 
    # => CONCAT(user.last_name, ', ', user.first_name)
    def func(name, *args)
      params = []
      args.each do |arg|
        if arg.is_a? SqlExpr
          params << arg
        else
          params << "'#{arg}'"
        end
      end
      return SqlExpr.new "#{name.to_s.upcase}(#{params.join(', ')})", self
    end     
      
    def raw(expr)
      return expression expr
    end
    
    def expression(expr)
      return SqlExpr.new expr, self
    end 
      
    def add_table(real_name, pseudonym)
      @tables[pseudonym] = real_name
      self.class.send(:define_method, pseudonym) do
        return SqlTable.new pseudonym, self
      end
    end  
    
    def add_column(column)
      @columns << column
      self.class.send(:define_method, column) do
        return expression column
      end    
    end      
      
  end


  class SqlTable
    def initialize(name, parent)
      @name = name   
      @parent = parent 
    end  

    undef id, class  

    def to_s
      return @name
    end

    def method_missing(symbol, *args)
      return SqlExpr.new "#{self.to_s}.#{symbol}", @parent
    end     
      
  end

  class SqlExpr

    def initialize(expr, parent)
      @expr = expr.to_s  
      @parent = parent   
    end
    
    undef id, class 
      
    def to_s
      return @expr
    end

    def expression(expr)
      return SqlExpr.new expr, @parent
    end 


    def process_operator(operator, val)
      return expression "#{self} #{operator} #{escape(val)}"
    end

    def escape(obj)
      if obj.nil?
        return "NULL"
      elsif obj.is_a? TrueClass
        return "TRUE"
      elsif obj.is_a? FalseClass
        return "FALSE"             
      elsif obj.is_a?(Integer) || obj.is_a?(Float) || obj.is_a?(SqlExpr)
        return obj.to_s
      else
        return "'" + obj.to_s.gsub(/'/, "\\\\'") + "'"
      end
    end

    def as(val)
      @parent.add_column val
      return process_operator('AS', val)
    end
    
    def >(val)
      return process_operator('>', val)
    end
    
    def <(val)
      return process_operator('<', val)
    end
        
    def >=(val)
      return process_operator('>=', val)
    end  

    def <=(val)
      return process_operator('<=', val)
    end 
    
    def +(val)
      return process_operator('+', val)
    end    
    
    def -(val)
      return process_operator('-', val)
    end   

    def *(val)
      return process_operator('*', val)
    end    
    
    def /(val)
      return process_operator('/', val)
    end  
    
    def like(val)
      return process_operator('LIKE', val)
    end   
    
    def make_list_str(list)
      list_str = '(' 
      list_str += list.map do |e| 
        escape(e)
      end.join(', ')
      list_str += ')'
      return list_str
    end
    
    # Generates SQL = (equal) operator
    def ==(val)
      if val.is_a? Array
        return process_operator('IN', make_list_str(val))
      else
        return process_operator('=', val)
      end
    end   

    # Generates SQL <> (not equal) operator
    def <=>(val)
      if val.is_a? Array
        return process_operator('NOT IN', make_list_str(val))
      else
        return process_operator('<>', val)
      end
    end 
    
    # Generates SQL AND operator
    # (a) & (b)
    # => (a) AND (b)
    # You must put both opernands in brackets, otherwise you can get an unexpected results
    def &(val)
      return expression "(#{self}) AND (#{val})"
    end 
    
    # Generates SQL OR operator
    # (a) | (b)
    # => (a) OR (b)
    # You must put both opernands in brackets, otherwise you can get an unexpected results    
    def |(val)
      return expression "(#{self}) OR (#{val})"
    end     
    
    def asc
      return expression "#{self} ASC"
    end    
    
    def desc
      return expression "#{self} DESC"
    end        
    
    def avg
      return @parent.func :avg, self
    end

    def min
      return @parent.func :min, self
    end
    
    def max
      return @parent.func :max, self
    end
    
    def count
      return @parent.func :count, self
    end    

    def sum
      return @parent.func :sum, self
    end 
    
  end  
end



