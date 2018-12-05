require 'sinatra'
require 'sinatra/reloader'
require 'mysql2'
require 'mysql2-cs-bind'
require 'pry'
require 'rack/flash'

enable :sessions

# flash
configure do
  use Rack::Flash
end

# db
def db
  @db ||= Mysql2::Client.new(
    host:     ENV['DB_HOST'] || 'localhost',
    port:     ENV['DB_PORT'] || '3306',
    username: ENV['DB_USERNAME'] || 'root',
    password: ENV['DB_PASSWORD'] || '',
    database: ENV['DB_DATABASE'] || 'gtb_db',
  )
end

# nl2br
def nl2br(string)
  if string
    string.gsub("\n\r","<br />").gsub("\r", "").gsub("\n", "<br />")
  end
end

# languages 一覧
def languages
  sql = 'SELECT * FROM languages'
  db.xquery(sql)
end

# language_name
def language_name(language_id)
  sql = 'SELECT name FROM languages WHERE id = ?'
  language_name = db.xquery(sql, language_id).to_a
  return language_name[0]['name']
end

# user_data
def user_data(user_id)
  sql = 'SELECT * FROM users WHERE id = ?'
  db.xquery(sql, user_id).to_a
end

# nickname
def user_nickname(user_id)
  sql = 'SELECT nickname FROM users WHERE id = ?'
  user_nickname = db.xquery(sql, user_id).to_a
  return user_nickname[0]['nickname']
end

# user books一覧
def books(user_id)
  sql = 'SELECT * FROM books WHERE user_id = ? ORDER BY language_id'
  db.xquery(sql, user_id).to_a
end

# ユーザーサムネイル保存
def user_image(user_id, file, filename)
  url = "./public/image/users/#{user_id}/"
  Dir::mkdir(url) unless Dir::exist?(url)

  open("#{url}#{filename}", 'wb') do |f|
    f.write(file.read)
  end
end

# book画像保存
def book_image(book_id, file, filename)
  url = "./public/image/books/#{book_id}/"
  Dir::mkdir(url) unless Dir::exist?(url)

  open("#{url}#{filename}", 'wb') do |f|
    f.write(file.read)
  end
end

# user_language
def user_language(user_id)
  sql = 'SELECT * FROM user_language WHERE user_id = ?'
  db.xquery(sql, user_id).to_a
end

# level
def levels
  levels = [
    '-',
    '★',
    '★★',
    '★★★',
    '★★★★',
    '★★★★★'
  ]
end

# index
get '/' do

  @h1 = 'あなたにおすすめの本'

  redirect '/signin' unless session[:name]

  @user_language = user_language(session[:user_id])

  redirect '/books' if @user_language.empty?

  sql = 'SELECT * FROM users
  INNER JOIN user_language ON users.id=user_language.user_id
  INNER JOIN books ON books.language_id=user_language.language_id
  WHERE user_language.level=books.level
  AND users.id= ?
  AND user_language.level != 0
  ORDER BY user_language.id'
  @recommended_books = db.xquery(sql, session[:user_id]).to_a

  erb :index
end


# language
get '/language/:language_id' do

  @h1 = 'あなたにおすすめの本'
  @language_id = params[:language_id]
  @language_name = language_name(@language_id)
  @user_language = user_language(session[:user_id])

  sql = 'SELECT * FROM users
  INNER JOIN user_language ON users.id=user_language.user_id
  INNER JOIN books ON books.language_id=user_language.language_id
  WHERE user_language.level=books.level
  AND users.id= ?
  AND books.language_id= ?
  AND user_language.level != 0
  ORDER BY user_language.id'
  @recommended_books = db.xquery(sql, session[:user_id], @language_id).to_a

  erb :language
end


# books
get '/books' do

  @h1 = 'All Books'
  sql = 'SELECT * FROM books ORDER BY language_id'
  @books = db.xquery(sql).to_a

  erb :books
end

get '/books/language/:language_id' do

  @h1 = language_name(params[:language_id])
  sql = 'SELECT * FROM books WHERE language_id = ?'
  @books = db.xquery(sql, params[:language_id]).to_a

  erb :books
end


# sign up
get '/signup' do

  @signup = true

  erb :signup
end

post '/signup' do

  sql = 'SELECT * FROM users WHERE name = ?'
  user = db.xquery(sql, params[:name]).to_a

  unless user.empty?
    flash[:sign] = 'この名前は既に使用されています。'
    return redirect '/signup'
  end

  sql = 'INSERT INTO users (name, nickname, password, created_at, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())'
  db.xquery(sql, params[:name], params[:nickname], params[:password]).to_a

  last_id = db.last_id
  session[:user_id] = last_id
  session[:name] = params[:name]
  session[:nickname] = params[:nickname]

  flash[:messege] = '登録しました。'

  redirect '/mypage'
end

# sign in
get '/signin' do
  erb :signin
end


# sign in
post '/signin' do

  sql = 'SELECT * FROM users WHERE name = ? AND password = ?'
  user = db.xquery(sql, params[:name], params[:password]).to_a

  if user.empty?
    flash[:sign] = 'ログインが失敗しました。'
    return redirect '/signin'
  end

  session[:user_id] = user[0]['id']
  session[:name] = user[0]['name']
  session[:nickname] = user[0]['nickname']
  session[:image] = user[0]['image']

  flash[:messege] = "こんにちは、#{user[0]['nickname']}さん"

  redirect '/'
end

get '/signout' do

  session[:user_id] = nil
  session[:name] = nil
  session[:nickname] = nil
  session[:image] = nil
  flash[:sign] = 'ログアウトしました。'

  redirect '/'
end


# my page
get '/mypage' do

  redirect '/' if session[:user_id].nil?

  @user_data = user_data(session[:user_id])
  @books = books(session[:user_id])
  @user_language = user_language(session[:user_id])
  session[:name] = @user_data[0]['name']

  erb :mypage
end


# user_edit
get '/user/:user_id/edit' do

  @user_data = user_data(params[:user_id])

  erb :user_edit
end

put '/user_edit' do

  unless params[:file].nil?
    filename = params[:file][:filename]
    file = params[:file][:tempfile]
    user_image(params[:user_id], file, filename)
  else
    user_data = user_data(params[:user_id]).to_a
    unless user_data.nil?
      filename = user_data[0]['image']
    end
  end

  sql = 'UPDATE users SET nickname = ?, password = ?, comment = ?, image = ?, updated_at = NOW() WHERE id = ?'
  db.xquery(sql, params[:nickname], params[:password], params[:comment], filename, params[:user_id]).to_a

  session[:image] = filename

  flash[:messege] = 'アカウント情報を更新しました。'

  redirect '/mypage'
end


# book_create
get '/book/:user_id/create' do

  @user_data = user_data(params[:user_id])
  @languages = languages

  erb :book_create
end

put '/book_create' do

  filename = nil
  unless params[:file].nil?
    filename = params[:file][:filename]
    file = params[:file][:tempfile]
  end

  sql = 'INSERT INTO books (title, link, image, language_id, level, comment, user_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP())'
  db.xquery(sql, params[:title], params[:link], filename, params[:language_id], params[:level],  params[:comment], params[:user_id]).to_a

  unless params[:file].nil?
    book_last_id = db.last_id
    book_image(book_last_id, file, filename)
  end

  flash[:messege] = '本を登録しました。'

  redirect '/mypage'
end



# book_edit
get '/book/:book_id/edit' do

  sql = 'SELECT * FROM books WHERE id = ?'
  @books = db.xquery(sql, params[:book_id]).to_a
  @languages = languages

  erb :book_edit
end

put '/book_edit' do

  filename = nil
  unless params[:file].nil?
    filename = params[:file][:filename]
    file = params[:file][:tempfile]
    book_image(params[:id], file, filename)
  else
    sql = 'SELECT * FROM books WHERE id = ?'
    book = db.xquery(sql, params[:id]).to_a
    unless book.nil?
      filename = book[0]['image']
    end
  end

  sql = 'UPDATE books SET title = ?, link = ?, image = ?, language_id = ?, level = ?, comment = ?, user_id = ? WHERE id = ?'
  db.xquery(sql, params[:title], params[:link], filename, params[:language_id], params[:level], params[:comment], params[:user_id], params[:id]).to_a

  flash[:messege] = '本を更新しました。'

  redirect '/mypage'
end


# level
get '/user/:user_id/level' do

  @user_language = user_language(params[:user_id]).to_a
  @user_data = user_data(params['user_id'])
  @languages = languages

  erb :user_level
end

put '/user_level' do

  user_language = user_language(params[:user_id])

  if user_language.empty?
    languages.each do |language|
      sql = "INSERT INTO user_language (user_id, language_id, level) VALUES (?, ?, ?)"
      db.xquery(sql, params[:user_id], language['id'], params[language['name']]).to_a

      flash[:messege] = 'スキルレベルを登録しました。'

    end
  else
    languages.each do |language|
      sql = "UPDATE user_language SET level = ? WHERE user_id = ? AND language_id = ?"
      db.xquery(sql, params[language['name']], params[:user_id], language['id']).to_a

      flash[:messege] = 'スキルレベルを更新しました。'
    end
  end

  redirect to('/mypage')
end
