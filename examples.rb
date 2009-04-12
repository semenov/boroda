require 'boroda'

puts '- ' * 40

sql = Boroda.build do
  from :posts 
  select :id, :name
  where (id == 5) & (name == "q'we")
end

puts sql
puts '- ' * 40

sql = Boroda.build do
  from :posts, :users
  select posts.*
  where (posts.author_id == users.id) & (users.name == 'Barack Obama')
end

puts sql
puts '- ' * 40

sql = Boroda.build do
  from :posts => :p
  left join :comments => :c
  on c.post_id == p.id
  select p.id, p.title, p.content, c.id.count => :comment_count
  group by p.id
  where (p.title.like '%programming%') | # Выбираем все посты, содержащие в заголовке 'programming'
        (p.rating > 5) # Или с рейтингом больше 5
  order by p.created_at.desc
  limit 10
  offset 20
end

puts sql
puts '- ' * 40

max_count = 7

sql = Boroda.build do
  from :posts, :accounts => :a, :users => :u
  left join :avatars, :secret_passwords => :pass
  on posts.id == avatars.post_id
  select posts.title, a.address.count => :adr, posts.name.count => :p_name, 
    (posts.rating.max + 5) => :max_posts_rating, 
    posts.price.avg => :avg_price, 
    func(:concat, posts.name, ' * ', posts.last_name) => :full_name
  where (a.max_rate > max_count + 6) | (avg_price <=> 100.5) & (a.id <=> [1, 5, 9, 7, nil])
  order by posts.name, a.price.desc
  limit 5
end

puts sql
puts '- ' * 40

current_user_id = 5
PostsLimit = 10
page = 7

sql = Boroda.build do
  from :posts => :p
  left inner join :comments => :c
  on p.id == c.post_id
  select p.id, p.title, p.content, c.id.count => :comment_count
  group by p.id
  where (p.user_id == current_user_id) & (p.active == true) & (func(:year, p.created_at) <=> 2008) & p.title.like('ruby%')
  having comment_count > 0
  order by p.created_at.desc
  limit PostsLimit
  offset PostsLimit * (page - 1)
end

puts sql

