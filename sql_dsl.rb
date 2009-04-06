class SqlDsl
  def construct(&block)
    @sql = []
    @tables = {}
    
    if block_given?
      instance_eval &block
      puts @sql
    end
  end
  
  def method_missing(symbol, *args) 
    if @tables.has_key? symbol
      SqlTable.new(symbol)
    else 
      raise NameError, "Unknown method or variable #{symbol}", caller
    end
  
  end    
  
  def sql
    @sql.join("\n")
  end
 
  def select(*fields)
    @sql << "SELECT " + fields.join(", ")
  end
  
  
  def from(*tables)
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
    @sql << "FROM " + tables_processed.join(", ")
  end
  
  def where(clause)
    @sql << "WHERE " + clause.to_s
  end   
  
  def having(clause)
    @sql << "HAVING " + clause.to_s
  end    
  
  def on(clause)
    @sql << "ON " + clause.to_s
  end   
  
  
  def limit(number, offset = 0)
    @sql << "LIMIT"
  end
  
  def order(*fields)
    @sql << "ORDER BY " + fields.join(", ")
  end   
  
  def group(*fields)
    @sql << "GROUP BY " + fields.join(", ")
  end   

  # Used for ORDER BY and GROUP BY
  def by(*fields)
    fields
  end    
  
  def desc(field)
    "#{field} DESC"
  end   
  
  def all
    "*"
  end  
  
  def _()
  end
    
  def func(name, *args)
    params = []
    args.each do |arg|
      if arg.is_a? SqlExpr
        params << arg
      else
        params << "'#{arg}'"
      end
    end
    SqlExpr.new "#{name.to_s.upcase}(#{params.join(', ')})"
  end     
    
# aggregate functions  
  
  def max(field)
    func :max, field
  end  
  
  def min(field)
    func :min, field
  end  

  def sum(field)
    func :sum, field
  end
   
  def avg(field)
    func :avg, field
  end   
    
  def count(field)
    func :count, field
  end  
    
private
  def add_table(real_name, pseudonym)
    @tables[pseudonym] = real_name
  end    
    
end


class SqlTable
  def initialize(name)
    @name = name    
  end  

  undef id, class  

  def to_s
    @name
  end

  def method_missing(symbol, *args)
    SqlExpr.new "#{self.to_s}.#{symbol}"
  end     
    
end

class SqlExpr

  def initialize(expr)
    @expr = expr.to_s    
  end
  
  def to_s
    @expr
  end

  def process_operator(operator, val)
    SqlExpr.new "#{self} #{operator} #{val}"
  end

  def as(val)
    process_operator('AS', val)
  end
  
  def ===(val)
    as(val)
  end  
  
  def >(val)
    process_operator('>', val)
  end

  def <(val)
    process_operator('<', val)
  end
  
  def +(val)
    process_operator('+', val)
  end    
  
  def -(val)
    process_operator('-', val)
  end   
  
  def ==(val)
    process_operator('=', val)
  end   

  def <=>(val)
    process_operator('<>', val)
  end 

  def &(val)
    SqlExpr.new "(#{self}) AND (#{val})"
  end 
  
  def |(val)
    SqlExpr.new "(#{self}) OR (#{val})"
  end     
  
  def desc
    SqlExpr.new "#{self} DESC"
  end        
  
end  

max_count = 7

sql = SqlDsl.new

sql.construct do
  from :posts, :accounts => :a, :users => :users
  select a.address, posts.name, posts.title, max(posts.rating), avg(posts.price), func(:concat, posts.name, ' * ', posts.last_name)
  where (a.max_rate > max_count + 6) | (a.price <=> 100.5)
  order by posts.name, a.price.desc
end

#sql.construct(:lolposts => :posts, :users => :u) do
#  select posts.*, posts.id, posts.name, posts.title, posts.rating.max.as(:max_rate), post.price.avg
#  from posts
#  where (max_rate > max_count + 6) | (product.price <=> 100.5) & (post.name.like 'asd%')
#  order by posts.name, product.price.desc
#end

