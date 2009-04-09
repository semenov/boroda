class SqlDsl
  def construct(&block)
    @sql_parts = {}
    @tables = {}
    @columns = []
    
    if block_given?
      instance_eval &block
    end
  end
  
  def method_missing(symbol, *args) 
    if @tables.has_key? symbol
      SqlTable.new(symbol, self)
    elsif @columns.include? symbol
      SqlExpr.new(symbol, self)
    else
      raise NameError, "Unknown method or variable #{symbol}", caller
    end
  end    
  
  def add_column(column)
    @columns << column
  end   
  
  def sql
    processed_parts = []
    [:select, :from, :join, :where, :group, :having, :order, :limit].each do |key|
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
  
  def on(clause)
    raise "You must use 'join' before using 'on'" if !@sql_parts.has_key? :join
    @sql_parts[:join] << "ON " + clause.to_s
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
    tables_processed.join(", ")    
  end
  
  def make_column_list(columns)
    columns.join(", ")
  end  
  
  def where(clause)
    @sql_parts[:where] = "WHERE " + clause.to_s
  end   
  
  def having(clause)
    @sql_parts[:having] = "HAVING " + clause.to_s
  end     
  
  
  def limit(number, offset = 0)
    @sql_parts[:limit] = "LIMIT " + number.to_s
    
  end
  
  def order(*fields)
    @sql_parts[:order] = "ORDER BY " + fields.join(", ")
  end   
  
  def group(*fields)
    @sql_parts[:group] = "GROUP BY " + fields.join(", ")
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
    SqlExpr.new "#{name.to_s.upcase}(#{params.join(', ')})", self
  end     
    
  def raw(expr)
    SqlExpr.new expr, self
  end 
  
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
  def initialize(name, parent)
    @name = name   
    @parent = parent 
  end  

  undef id, class  

  def to_s
    @name
  end

  def method_missing(symbol, *args)
    SqlExpr.new "#{self.to_s}.#{symbol}", @parent
  end     
    
end

class SqlExpr

  def initialize(expr, parent)
    @expr = expr.to_s  
    @parent = parent   
  end
  
  def to_s
    @expr
  end

  def process_operator(operator, val)
    SqlExpr.new "#{self} #{operator} #{val}", @parent
  end

  def as(val)
    @parent.add_column val
    return process_operator('AS', val)
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
    SqlExpr.new "(#{self}) AND (#{val})", @parent
  end 
  
  def |(val)
    SqlExpr.new "(#{self}) OR (#{val})", @parent
  end     
  
  def desc
    SqlExpr.new "#{self} DESC", @parent
  end        
  
  def avg
    @parent.func :avg, self
  end

  def min
    @parent.func :min, self
  end
  
  def max
    @parent.func :max, self
  end
  
  def count
    @parent.func :count, self
  end    
  
end  

max_count = 7

sql = SqlDsl.new

sql.construct do
  from :posts, :accounts => :a, :users => :u
  left join :avatars, :secret_passwords => :pass
  on posts.id == avatars.post_id
  select count(a.address).as(:adr), posts.name.count.as(:p_name), posts.title, (max(posts.rating) + 5).as(:max_posts_rating), 
    posts.price.avg.as(:avg_price), func(:concat, posts.name, ' * ', posts.last_name)
  where (a.max_rate > max_count + 6) | (avg_price <=> 100.5)
  order by posts.name, a.price.desc
  limit 5
end

puts sql

#sql.construct(:lolposts => :posts, :users => :u) do
#  select posts.*, posts.id, posts.name, posts.title, posts.rating.max.as(:max_rate), post.price.avg
#  from posts
#  where (max_rate > max_count + 6) | (product.price <=> 100.5) & (post.name.like 'asd%')
#  order by posts.name, product.price.desc
#end

