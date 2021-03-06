{catchErrors, expect, reqres, stub, protect} = require '../test_helper'
protect()
RegistrationController = require '../../app/controllers/registration'

registerWith = (data, done, callback) ->
  reqres (req, res) ->
    req.method = 'POST'
    params =
      controller: 'registration'
      action: 'register'
    req.body = data
    stub RegistrationController.prototype, "render", catchErrors done, (next) ->
      RegistrationController.prototype.render.restore()
      catchErrors(done, callback).call this
    RegistrationController.handle params, req, res, ->
      console.log new Error().stack
      done new Error("Didn't render?")

describe 'RegistrationController', ->
  it 'grants first user base and owner roles automatically', (done) ->
    models = @_models
    data =
      fullname: 'Southampton Makerspace'
      email: 'example@example.com'
      username: 'Testing'
      address: 'Unit K6, Pitt Road, Southampton, SO15 3FQ'
      password:  's3kr17??'
      password2: 's3kr17??'
      terms: 'on'
    registerWith.call this, data, done, (err) ->
      return done err if err
      expect(@template).to.eql "success"
      models.User.getLast catchErrors done, (err, user) ->
        return done err if err
        expect(user.meta.verified).to.not.exist
        user.getActiveRoles catchErrors done, (err, roles) ->
          return done err if err
          expect(roles).to.have.length(2)
          expect([roles[0].name, roles[1].name].sort()).to.eql ['Friend', 'Trustee']
          done()

  it 'requires approval for further users', (done) ->
    models = @_models
    data =
      fullname: 'User Two'
      email: 'user2@example.com'
      username: 'User2'
      address: 'Unit K6, Pitt Road, Southampton, SO15 3FQ'
      password:  's3kr17??'
      password2: 's3kr17??'
      terms: 'on'
    registerWith data, done, (err) ->
      return done err if err
      expect(@template).to.eql "success"
      models.User.getLast catchErrors done, (err, user) ->
        return done err if err
        expect(user.meta.verified).to.not.exist
        user.getActiveRoles catchErrors done, (err, roles) ->
          return done err if err
          expect(roles).to.have.length(0)
          done()

  it 'requires passwords to match', (done) ->
    data =
      fullname: 'Southampton Makerspace'
      email: 'example@example.com'
      username: 'Testing'
      address: 'Unit K6, Pitt Road, Southampton, SO15 3FQ'
      password:  's3kr17!?'
      password2: 's3kr17?!'
      terms: 'on'
    registerWith data, done, (err) ->
      return done err if err
      expect(@template).to.eql "register"
      expect(@errors).to.be.an 'object'
      expect(@errors.password).to.eql ['Passwords do not match']
      done()
