class SqlDsl
  def construct(&block)
    @sql = []
    if block_given?
      instance_eval &block
      puts @sql
    end
  end
  
  def method_missing(symbol, *args)
    symbol
  end    
  
  def sql
    @sql.join("\n")
  end
 
  def select(*fields)
    @sql << "SELECT " + fields.join(", ")
  end
  
  def from(*tables)
    @sql << "FROM " + tables.join(", ")
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
    
# aggregate functions  
  
  def max(field)
    :"MAX(#{field})"
  end  
  
  def min(field)
    :"MIN(#{field})"
  end  

  def sum(field)
    :"SUM(#{field})"
  end
   
  def avg(field)
    :"AVG(#{field})"
  end   
    
  def count(field)
    :"COUNT(#{field})"
  end  
    
end

class Symbol

  def process_operator(operator, val)
    :"#{self} #{operator} #{val}"
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
    :"(#{self}) AND (#{val})"
  end 
  
  def |(val)
    :"(#{self}) OR (#{val})"
  end 
  
  def method_missing(symbol, *args)
    :"#{self}.#{symbol}"
  end  
  
  undef id, class
end  

max_count = 7

sql = SqlDsl.new

sql.construct do
  select :object.if === :pid, :posts.name, :posts.title, max(:posts.rating).as(:max_rate), avg(:price), price
  from :posts === :p
  where (:max_rate > max_count + 6) | (:price <=> 100.5)
  order by :name, desc(:price)
end

#sql.construct(:lolposts => :posts, :users => :u) do
#  select posts.*, posts.id, posts.name, posts.title, posts.rating.max.as(:max_rate), post.price.avg
#  from posts
#  where (max_rate > max_count + 6) | (product.price <=> 100.5) & (post.name.like 'asd%')
#  order by posts.name, product.price.desc
#end

