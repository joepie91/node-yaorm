require("pretty-error").start().skipPackage("bluebird", "coffee-script").skipNodeFiles()

Promise = require "bluebird"
#Promise.longStackTraces()

yaorm = require("./")({
	driver: "pg"
	hostname: "localhost"
	username: "postgres"
	database: "team"
})

yaorm.defineModel "User",
	tableName: "users"
	columns: ["id", "username", "display_name", "email_address", "hash", "external_identifier", "external_authentication", "created_at", "updated_at", "activated", "activation_key"]
	relations:
		"projects": yaorm.hasMany("Project", foreignKey: "owner_id")

yaorm.defineModel "Project",
	tableName: "projects"
	columns: ["id", "owner_id", "public", "name", "slug", "description", "created_at", "updated_at", "default_permissions"]
	relations:
		"owner": yaorm.belongsTo("User", foreignKey: "owner_id")

Promise.try ->
	yaorm.model("Project").getAll(relations: "owner")
.map (project) -> [project.name, project.owner.display_name]
.then (projects) ->
	console.log projects
.catch (err) ->
	console.log err.stack

### TODO:
* Nested relations
* More complex relations (many-to-many?)
* Save (UPDATE + INSERT)
* Deep save (incl. nested relations)
###
