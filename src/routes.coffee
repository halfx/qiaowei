{
  user
  postSchedule
  content
  org
  connectDb
}                              = require './models'
fs = require 'fs'
path = require 'path'
connectDb (err)->
  if err
    console.error err 
    process.exit 1
config = require './../config.js'
authorize = require './../sdk/authorize.js'
Sina = require './../sdk/sina.js',
TQQ =  require './../sdk/tqq.js',
RenRen = require './../sdk/renren.js',
Douban = require './../sdk/douban.js'
sina = new Sina(config.sdks.sina)
tqq = new TQQ(config.sdks.tqq)
renren = new RenRen(config.sdks.renren)
douban = new Douban(config.sdks.douban)
_ = require 'underscore'
module.exports                 = class Routes
  constructor                  : (app)->
    @mount app if app?
  mount                        : (app)->

    app.get '*',(req,res,next)->
      return next() unless req.session.username
      user.findOne({name:req.session.username})
      .populate('owns')
      .populate('editorOf')
      .populate('posterOf')
      .exec (err,item)->
        res.locals.user = item
        next err

    app.get '/logout',(req,res,next)->
      req.session.username= null
      res.redirect '/login'

    app.get '/login',(req,res,next)->
      res.locals.authorize = {
        "login" : authorize.sina(config.sdks.sina)
      }
      res.render 'login'



    
    app.get '/sina_auth_cb', (req, res, next) ->
      sina.oauth.accesstoken req.query.code , (error, data)->
        access_token = data.access_token 
        sina.users.show {source:config.sdks.sina.app_key,uid:data.uid,access_token:access_token,method:"GET"}, (error, data)->
          name = data.screen_name
          user.findOne {name:name},(err,item)->
          item = new user() unless item
          item.name= name
          item.sinaToken= access_token
          item.save (err)->
            req.session.username = name
            res.redirect("/")


    app.get '*',(req,res,next)->
      if res.locals.user    
        next()
      else
        res.redirect '/login'

 
    app.get '/tqq_auth_cb', (req, res, next) ->
      res.locals.user.qqToken.pop()
      res.locals.user.qqToken.pop()
      return next() unless req.query.code
      tqq.oauth.accesstoken req.query.code , (error, data)->
        access_token = data.access_token
        openid = data.openid
        tqq.user.info {clientip:"115.193.182.232",openid:openid,access_token:access_token},(error,data)->
          name = data.data.nick
        res.locals.user.qqToken.pop()
        res.locals.user.qqToken.pop()
        res.locals.user.qqToken.push access_token
        res.locals.user.qqToken.push openid
        next()

    app.get '/tqq_auth_cb', (req, res, next) ->    
      res.locals.user.save next
    app.get '/tqq_auth_cb', (req, res, next) ->
      res.redirect("/")


    app.get '/renren_auth_cb', (req, res, next) ->
      res.locals.user.renrenToken= null
      return next() unless req.query.code
      renren.oauth.accesstoken req.query.code , (error, data)->
        access_token = data.access_token
        renren.users.getInfo {access_token:access_token},(error,data)->
          name = data[0].name
        res.locals.user.renrenToken= access_token
        console.log res.locals.user

    app.get '/renren_auth_cb', (req, res, next) ->    
      res.locals.user.save next
    app.get '/renren_auth_cb', (req, res, next) ->
      res.redirect("/")



       
    app.get '/douban_auth_cb', (req, res, next) ->
      res.locals.user.doubanToken= null
      return next() unless req.query.code
      douban.oauth.accesstoken req.query.code , (error, data)->
        access_token = data.access_token
        douban.user.me {access_token:access_token}, (error,data)->
          name=data.name
        res.locals.user.doubanToken= access_token

    app.get '/douban_auth_cb', (req, res, next) ->    
      res.locals.user.save next
    app.get '/douban_auth_cb', (req, res, next) ->
      res.redirect("/")


    app.get '/',(req,res,next)->
      res.locals.userOrg= res.locals.user.owns[0]||res.locals.user.editorOf[0]||res.locals.user.posterOf[0]||null
      res.locals.authorize = 
        "logout" : authorize.sina(_.extend({forcelogin:true},config.sdks.sina))
        "sina" : authorize.sina(config.sdks.sina)
        "renren" : authorize.renren(config.sdks.renren)
        "douban" : authorize.douban(config.sdks.douban)
        "tqq" : authorize.tqq(config.sdks.tqq)
      res.render 'i'



    app.all '/org/new/',(req,res,next)->
      res.locals.org = new org
        owner: res.locals.user
      
      res.locals.org.save next
    app.all '/org/new/',(req,res,next)->
      res.redirect "/org/#{res.locals.org._id}/"

    app.all '/org/:id/*',(req,res,next)->
      org.findById(req.params.id).populate('postSchedules')
      .populate('editors')
      .populate('posters')
      .populate('contents').exec (err,item)->
        res.locals.org = item 
        next err

    app.all '/org/:id/*',(req,res,next)->
      return res.send 404 unless res.locals.org
      next()
    app.get '/org/:id/',(req,res,next)->
      res.render 'org'

    app.post '/org/:id/save',(req,res,next)->
      res.locals.org[k]= v for k,v of req.body.org
      res.locals.org.save next

    app.post '/org/:id/remove',(req,res,next)->
      res.locals.org.remove next


    app.all '/org/:id/setHead',(req,res,next)->
      headPath= path.join(__dirname,'..','assets',"org#{res.locals.org._id}head.jpg")
      if req.files.file&&req.files.file.name
        stream= fs.createReadStream req.files.file.path
        stream.pipe fs.createWriteStream headPath 
        fs.on 'close',next
      else
        fs.unlink headPath,(err)->
          next()
    app.all '/org/:id/setFoot',(req,res,next)->
      headPath= path.join(__dirname,'..','assets',"org#{res.locals.org._id}foot.jpg")
      if req.files.file&&req.files.file.name
        stream= fs.createReadStream req.files.file.path
        stream.pipe fs.createWriteStream headPath 
        fs.on 'close',next
      else
        fs.unlink headPath,(err)->
          next()

    app.all '/org/:id/:method',(req,res,next)->
      res.redirect 'back'




    app.post '/org/:id/editor/new',(req,res,next)->
      user.findOne {name:req.body.user.name},(err,item)->
        res.locals.newEditor = item
        next err




    app.post '/org/:id/editor/new',(req,res,next)->
      return res.send 404 unless res.locals.newEditor
      next()
    app.post '/org/:id/editor/new',(req,res,next)->
      res.locals.newEditor.editorOf.push res.locals.org
      res.locals.org.editors.push res.locals.newEditor
      res.locals.org.save next

    app.post '/org/:id/editor/new',(req,res,next)->
      res.locals.newEditor.save next

    app.post '/org/:id/editor/new',(req,res,next)->
      res.redirect 'back'




    app.post '/org/:id/poster/new',(req,res,next)->
      user.findOne {name:req.body.user.name},(err,item)->
        res.locals.newPoster = item
        next err

    app.post '/org/:id/poster/new',(req,res,next)->
      return res.send 404 unless res.locals.newPoster
      next()
    app.post '/org/:id/poster/new',(req,res,next)->
      res.locals.newPoster.posterOf.push res.locals.org
      res.locals.org.posters.push res.locals.newPoster
      res.locals.org.save next

    app.post '/org/:id/poster/new',(req,res,next)->
      res.locals.newPoster.save next

    app.post '/org/:id/poster/new',(req,res,next)->
      res.redirect 'back'





    app.all '/postSchedule/new/',(req,res,next)->
      res.locals.postSchedule = new postSchedule()
      res.locals.postSchedule.save next
    app.all '/postSchedule/new/',(req,res,next)->
      res.redirect "/postSchedule/#{res.locals.postSchedule._id}/"


    app.all '/postSchedule/:id/*',(req,res,next)->
      postSchedule.findById req.params.id,(err,item)->
        res.locals.postSchedule = item
        next err

    app.all '/postSchedule/:id/*',(req,res,next)->
      return res.send 404 unless res.locals.postSchedule
      next()
    app.get '/postSchedule/:id/',(req,res,next)->
        res.render 'postSchedule'


    app.post '/postSchedule/:id/save',(req,res,next)->
      res.locals.postSchedule[k]= v for k,v of req.body.postSchedule
      res.locals.postSchedule.save next

    app.post '/postSchedule/:id/remove',(req,res,next)->
      res.locals.postSchedule.remove next

    app.post '/postSchedule/:id/:method',(req,res,next)->
      res.redirect 'back'






    app.all '/content/new/',(req,res,next)->
      res.locals.content = new content()
      res.locals.content.save next
    app.all '/content/new/',(req,res,next)->
      res.redirect "/content/#{res.locals.content._id}/"


    app.all '/content/:id/*',(req,res,next)->
      content.findById req.params.id,(err,item)->
        res.locals.content = item
        next err

    app.all '/content/:id/*',(req,res,next)->
      return res.send 404 unless res.locals.content
      next()
    app.get '/content/:id/',(req,res,next)->
      res.render 'content'

    app.post '/content/:id/save',(req,res,next)->
      res.locals.content[k]= v for k,v of req.body.content
      res.locals.content.save next

    app.post '/content/:id/remove',(req,res,next)->
      res.locals.content.remove next

    app.post '/content/:id/:method',(req,res,next)->
      res.redirect 'back'
    
