component {
	any function init(
		required string dsn,
		required array directories,
		required string tablename,
		boolean enabled=true
	) {
		variables.dsn = arguments.dsn;
		variables.directories = arguments.directories;
		variables.tablename = arguments.tablename;
		variables.enabled = arguments.enabled;
		variables.complete = false;
		return this;
	}

	// returns all migration scripts for given directories
	array function listAllMigrations() {
		var migrationScripts = [];
		for (var dir in variables.directories) {
			arrayAppend(directoryList(path=variables.directory, recurse=false, listInfo="path", filter="*.cfc|*.cfm", type="file"), true);
		}
		return migrationScripts;
	}

	// returns all migration scripts to run
	array function listMigrationsToDeploy() {
		// listAllMigrations with listMigrationsDeployed removed
		return [];
	}

	// returns all migration scripts that have already been run
	array function listMigrationsDeployed() {
		return [];
	}

	function runMigrations(function before, function after) {
		// get migration scripts
		lock name="runMigrations" scope="server" {
			if (!variables.complete) {
				lock name="deployMigrations" scope="server" {
					pipeline = listMigrationsToDeploy();
					transaction action="begin" isolation="read_committed" {
						var success = false;
						for (var it in pipeline) {
							if (structKeyExists(arguments, "before")) {
								before(it);
							}
							var type = listLast(".");
							switch (type) {
								case "cfm";
									success = runTemplate(it);
									break;
								case "cfc";
									success = runComponent(it);
									break;
							}
							if (structKeyExists(arguments, "after")) {
								after(it, success);
							}
							if (success) {
								// log that it's run on this server/instance
								logIt();
							} else {
								// log that it's failed on this server/instance
								logIt();
								transaction action="rollback";
								// exit the loop
								break;
							}
						}
					}
				}
			}
			variables.complete = true;
		}
	}

	boolean function runComponent(required string script) {
		// get migration scripts
		var deployment = createObject("component", getDottedPath(script));
		deployment.init(dsn=variables.dsn);
		if (structKeyExists(deployment, "canRun") && !deployment.canRun()) {
			// can't run - this could be a db migration that has already run on another server in the cluster
			return false;
		}
		return deployment.run();
		//deployment.setBeanFactory();
	}

	boolean function runTemplate(required string script) {
		// get migration scripts
		var success = false;
		var output = "";
		try {
			savecontent variable="output" {
				include "#script#";
			}
			success = true;
		} catch (any e) {
			var output = e.message;
			success = false;
		}
		return success;
	}

	// private
	string function getDottedPath(required string script) {
		return reReplace(script, "(/|\)", ".", "all");
	}

}
