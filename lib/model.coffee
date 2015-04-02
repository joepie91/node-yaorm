Promise = require "bluebird"
util = require "util"

Record = require "./record"

module.exports = class Model
	constructor: (@name, @options) ->
		# FIXME: Validation! tableName
		@_isInstance = false
		@options.idAttribute ?= "id"

	_getInstance: ->
		if @_isInstance
			return this
		else
			instance = Object.create(this)
			instance._isInstance = true
			instance._queryBuilder = @_YAORM.knex(@options.tableName)
			return instance

	_fromQuery: (qbFunc) ->
		instance = @_getInstance()
		qbFunc(instance._queryBuilder)
		return instance

	_where: (whereStatements) ->
		@_fromQuery (queryBuilder) ->
			queryBuilder.where whereStatements

	_all: ->
		# We don't need to add anything to the query here, since we want all the records.
		@_getInstance()

	_createResultHandler: (options = {}) ->
		return (rows) =>
			self = this

			Promise.map rows, (row) =>
				# FIXME: Can this be done with a JOIN, perhaps?
				record = self._createRecord()
				record.isNew = false
				record._setData(row)

				if not options.relations?
					options.relations = []
				else if not util.isArray(options.relations)
					options.relations = [options.relations]

				record._loadRelations(options.relations ? [], row)
			.then (rows) ->
				if (options.single ? false)
					if rows.length > 0
						return rows[0]
					else
						# FIXME: Error
				else
					if rows.length > 0 or (options.required ? true) == false
						return rows
					else
						# FIXME: Error

	_createResultHandlerSingle: (options = {}) ->
		options.single = true
		@_createResultHandler(options)

	_createResultHandlerCount: (options = {}) ->
		return (rows) =>
			return rows[0].CNT

	_createRecord: ->
		record = new Record()
		record._setModel(this)
		return record

	_populateRecord: (record, data) ->
		record._setData(data)

	_getRelations: (relations, data) ->
		Promise.try =>
			relationKeys = Object.keys(relations)

			Promise.map relationKeys, (attribute) =>
				# FIXME: Shallow-clone these options? Immutability etc.
				options = relations[attribute]

				switch options.type
					when "hasOne" then @_getHasOne(options.modelName, options, data)
					when "hasMany" then @_getHasMany(options.modelName, options, data)
					when "belongsTo" then @_getBelongsTo(options.modelName, options, data)
			.reduce ((obj, remoteRecord, i) ->
				obj[relationKeys[i]] = remoteRecord
				return obj
			), {}

	_getSimpleRelation: (modelName, options, data) ->
		Promise.try =>
			remoteModel = @_YAORM.model(modelName)

			switch options.type
				when "hasOne", "hasMany" then options.localKey ?= remoteModel.options.idAttribute
				when "belongsTo" then options.remoteKey ?= remoteModel.options.idAttribute

			whereStatements = {}
			whereStatements[options.remoteKey] = data[options.localKey]
			options.query ?= (->)

			queryBuilder = remoteModel
				._where whereStatements
				._fromQuery(options.query)
				.query()

			if (options.single ? false)
				queryBuilder
					.limit 1
					.then remoteModel._createResultHandlerSingle(options)
			else
				queryBuilder
					.then remoteModel._createResultHandler(options)

	# The logic regarding which is the localKey and which is the remoteKey, is handled in the YAORM instance.
	_getHasOne: (modelName, options, data) ->
		options.single = true
		@_getSimpleRelation(modelName, options, data)

	_getHasMany: (modelName, options, data) ->
		@_getSimpleRelation(modelName, options, data)

	_getBelongsTo: (modelName, options, data) ->
		options.single = true
		@_getSimpleRelation(modelName, options, data)

	create: (data) ->
		record = @_createRecord()
		record.isNew = true
		return record

	query: ->
		return @_queryBuilder

	find: (id, options = {}) ->
		whereStatements = {}
		whereStatements[@options.idAttribute] = id
		@getOneWhere(whereStatements, options)

	getOneWhere: (whereStatements, options = {}) ->
		@_where(whereStatements)
			.query()
			.limit(1)
			.then(@_createResultHandlerSingle(options))

	getAllWhere: (whereStatements, options = {}) ->
		@_where(whereStatements)
			.query()
			.then(@_createResultHandler(options))

	countWhere: (whereStatements, options = {}) ->
		@_where(whereStatements)
			.query()
			.count("#{@options.idAttribute} as CNT")
			.then(@_createResultHandlerCount(options))

	getOneFromQuery: (qbFunc, options = {}) ->
		@_fromQuery(qbFunc)
			.query()
			.limit(1)
			.then(@_createResultHandlerSingle(options))

	getAllFromQuery: (qbFunc, options = {}) ->
		@_fromQuery(qbFunc)
			.query()
			.then(@_createResultHandler(options))

	countFromQuery: (qbFunc, options = {}) ->
		@_fromQuery(qbFunc)
			.query()
			.count("#{@options.idAttribute} as CNT")
			.then(@_createResultHandlerCount(options))

	getAll: (options = {}) ->
		@_all()
			.query()
			.then(@_createResultHandler(options))

	countAll: (options = {}) ->
		@_all()
			.query()
			.count("#{@options.idAttribute} as CNT")
			.then(@_createResultHandlerCount(options))
