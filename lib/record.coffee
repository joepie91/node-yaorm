Promise = require "bluebird"

_shallowClone = (obj) ->
	newObject = {}
	for key, value of obj
		newObject[key] = value
	return newObject

module.exports = class Record
	constructor: ->
		@_data = {}
		@_savedData = {}
		@_changedData = {}

	_setModel: (model) ->
		self = this

		@_model = model

		if model.options.columns?
			model.options.columns.forEach (column) =>
				Object.defineProperty this, column,
					get: -> self.get column
					set: (value) -> self.set column, value

	_setData: (data) ->
		# We might need a deep clone here?
		@_data = _shallowClone(data)
		@_savedData = _shallowClone(data)

	_loadRelations: (relations, data) ->
		Promise.map relations, (relation) =>
			{key: relation, value: @_model.options.relations[relation]}
		.reduce ((obj, relationData) =>
			obj[relationData.key] = relationData.value
			return obj
		), {}
		.then (relations) =>
			@_model._getRelations(relations, data)
		.then (relations) =>
			for attribute, record of relations
				this[attribute] = record

			return this

	_saveAttributes: (attributes) ->
		null # do stuff

		# Upon success...
		@_savedData = @_data
		@_changedData = {}

	get: (attribute) ->
		return @_data[attribute]

	set: (attribute, value) ->
		@_data[attribute] = value
		@_changedData[attribute] = value

	save: ->
		# This only saves the changed attributes - it is almost always what you want.
		@_saveAttributes(@_changedData)

	saveAll: ->
		# This saves *all* the attributes as they are currently set in the object - even if something else has changed them in the database in the meantime. You probably don't need this.
		@_saveAttributes(@_data)
