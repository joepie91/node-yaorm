Model = require "./model"
knex = require "knex"

class YAORM
	constructor: (options) ->
		@_models = {}

		if options.knex?
			@knex = options.knex
		else if options.hostname?
			@knex = knex({
				client: switch options.driver
					# Some aliases...
					when "postgres", "postgresql" then "pg"
					when "mysql" then "mysql2"
					else options.driver
				connection:
					host: options.hostname
					user: options.username
					password: options.password
					database: options.database
					charset: options.charset ? "utf8"
				debug: options.debug ? false
			})
		else if options.knexfile?
			knexfile = require "knexfile"

			if knexfile.connection?
				# Basic configuration
				@knex = knex(knexfile)
			else
				# Environment configuration
				if not options.environment?
					# FIXME: Error
					null
				@knex = knex(knexfile[options.environment])
		else
			# FIXME: Error

	_registerModel: (model) ->
		model._YAORM = this
		@_models[model.name] = model
		return this

	_createRelation: (type, options) ->
		options.type = type
		return options

	loadModel: (modelPath) ->
		# We use the existing model as a prototype, so that we don't run into conflicts if two different YAORM instances were to use the same loaded model.
		baseModel = require(modelPath)
		model = Object.create(baseModel)
		@_registerModel(model)

	defineModel: (modelName, options) ->
		model = new Model(modelName, options)
		@_registerModel(model)

	model: (modelName) ->
		return @_models[modelName]

	express: ->
		return (req, res, next) ->
			null
			next()

	hasOne: (modelName, options = {}) ->
		if options.foreignKey?
			options.remoteKey = options.foreignKey
			delete options.foreignKey

		options.modelName = modelName
		@_createRelation "hasOne", options

	hasMany: (modelName, options = {}) ->
		if options.foreignKey?
			options.remoteKey = options.foreignKey
			delete options.foreignKey

		options.modelName = modelName
		@_createRelation "hasMany", options

	belongsTo: (modelName, options = {}) ->
		if options.foreignKey?
			options.localKey = options.foreignKey
			delete options.foreignKey

		options.modelName = modelName
		@_createRelation "belongsTo", options

exportMethod = (options) ->
	return new YAORM(options)

exportMethod.defineModel = (modelName, options) ->
	return new Model(modelName, options)

module.exports = exportMethod
