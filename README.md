Boroda
======

Boroda is a tiny library to genreate SQL SELECT statements. The library provides a DSL which is as close as possible to SQL. Just look at the code:

    require 'boroda'
    
    sql = Boroda.build do
      from :posts, :users
      select posts.*
      where (posts.author_id == users.id) & (users.name == 'Vlad Semenov')
    end

The result:

    SELECT posts.*
    FROM posts, users
    WHERE (posts.author_id = users.id) AND (users.name = 'Vlad Semenov')

As you see we are writing SQL queries in a pure ruby. Let's try to make something a little bit more complex.

    min_rating = 5
    sql = Boroda.build do
      from :posts => :p
      left join :comments => :c
      on c.post_id == p.id
      select p.id, p.title, p.content, c.id.count => :comment_count
      group by p.id
      where (p.title.like '%programming%') | # select all posts containing 'programming' in the title
            (p.rating > min_rating) # or having the rating greater than 5
      order by p.created_at.desc
      limit 10
      offset 20
    end

The result:

    SELECT p.id, p.title, p.content, COUNT(c.id) AS comment_count
    FROM posts AS p
    LEFT JOIN comments AS c
    ON c.post_id = p.id
    WHERE (p.title LIKE '%programming%') OR (p.rating > 5)
    GROUP BY p.id
    ORDER BY p.created_at DESC
    LIMIT 10
    OFFSET 20


Now let's see how to write queries using Boroda in general. Due to some techical limitations it was nessesary to change an order of SQL statements. The `from` method must be called first. A table name should be a symbol. You can specify aliases of tables passing a hash to the method like it is done in the second code snippet. Next you should specify `joins`. The order you can call DSL methods:

    from tables
    [[left|right] [outer|inner] join tables
    on condition | using columns
    [..]]
    [select columns]
    [ where condition
    | group by columns
    | having condition
    | order by columns
    | limit number
    | offset number ]*

In other words, you can call all methods from the last group in any order. Boroda will take care of building a correct SQL query.

The `condition` which is used in `where` and `having` ca. Использование следующих операторов имеет точно такой же смысл, какой они имеют в SQL:
+, -, *, /, >, <, >=, <=.

Due to some of Ruby limitations on operator overloading several operators vary from their SQL originals:

    a == b    # =>  a = b
    a <=> b   # =>  a <> b
    (a) & (b) # =>  (a) AND (b)
    (a) | (b) # =>  (a) OR (b)

*Warning!* It is absolutely necessary to use brackets around operands in last two cases. Otherwise you can get an unepected results. It is connected with the fact that this to operators have a very high priority in Ruby.

I don't recommend to use use Boroda in production as far as it could be vulnerable to SQL injectiong.

By the way, boroda (борода) is the Russian for 'beard'.

