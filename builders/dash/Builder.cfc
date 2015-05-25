component extends="builders.html.Builder" {

// PUBLIC API
	public void function build( docTree, buildDirectory ) {
		var tree          = docTree.getTree();
		var docsetRoot    = arguments.buildDirectory & "/lucee.docset/";
		var contentRoot   = docsetRoot & "Contents/";
		var resourcesRoot = contentRoot & "Resources/";
		var docsRoot      = resourcesRoot & "Documents/";


		if ( !DirectoryExists( arguments.buildDirectory ) ) { DirectoryCreate( arguments.buildDirectory ); }
		if ( !DirectoryExists( docsetRoot               ) ) { DirectoryCreate( docsetRoot               ); }
		if ( !DirectoryExists( contentRoot              ) ) { DirectoryCreate( contentRoot              ); }
		if ( !DirectoryExists( resourcesRoot            ) ) { DirectoryCreate( resourcesRoot            ); }
		if ( !DirectoryExists( docsRoot                 ) ) { DirectoryCreate( docsRoot                 ); }

		try {
			_setupSqlLite( resourcesRoot );

			for( var page in tree ) {
				_writePage( page, docsRoot, docTree );
				_storePageInSqliteDb( page );
			}
		} catch ( any e ) {
			rethrow;
		} finally {
			_closeDbConnection();
		}

		_copyResources( docsetRoot );
		_renameSqlLiteDb( resourcesRoot );
	}

	public string function renderLink( any page, required string title ) {

		if ( IsNull( arguments.page ) ) {
			return '<a class="missing-link">#HtmlEditFormat( arguments.title )#</a>';
		}

		var link = page.getId() & ".html";

		return '<a href="#link#">#HtmlEditFormat( arguments.title )#</a>';
	}

// PRIVATE HELPERS
	private string function _getHtmlFilePath( required any page, required string buildDirectory ) {
		if ( arguments.page.getPath() == "/home" ) {
			return arguments.buildDirectory & "/index.html";
		}

		return arguments.buildDirectory & arguments.page.getId() & ".html";
	}

	private void function _copyResources( required string rootDir ) {
		FileCopy( "/builders/dash/resources/Info.plist", arguments.rootDir & "Contents/Info.plist" );
		FileCopy( "/builders/dash/resources/icon.png", arguments.rootDir & "icon.png" );
	}

	private void function _setupSqlLite( required string rootDir ) {
		variables.sqlite = _getSqlLiteCfc();
		variables.dbFile = sqlite.createDb( dbName="docSet", destDir=arguments.rootDir & "/" );
		variables.dbConnection  = sqlite.getConnection( dbFile );

		sqlite.executeSql( dbFile, "CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)", false, dbConnection );
		sqlite.executeSql( dbFile, "CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path)", false, dbConnection );
	}

	private any function _getSqlLiteCfc() {
		return new api.sqlitecfc.SqliteCFC(
			  tempdir        = ExpandPath( "/api/sqlitecfc/tmp/" )
			, libdir         = ExpandPath( "/api/sqlitecfc/lib/" )
			, model_path     = "/api/sqlitecfc"
			, dot_model_path = "api.sqlitecfc"
		);
	}

	private void function _storePageInSqliteDb( required any page ) {
		var data = {};

		switch( page.getPageType() ){
			case "function":
				data = { name=page.getSlug(), type="Function" };
			break;
			case "tag":
				data = { name=page.getSlug(), type="Tag" };
			break;
			case "category":
				data = { name=Replace( page.getTitle(), "'", "''", "all" ), type="Category" };
			break;
			default:
				data = { name=Replace( page.getTitle(), "'", "''", "all" ), type="Guide" };
		}

		data.path = ReReplace( page.getPath(), "^/", "" ) & ".html";

		sqlite.executeSql( dbFile, "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('#data.name#', '#data.type#', '#data.path#')", false, dbConnection );

		for( var child in page.getChildren() ){
			_storePageInSqliteDb( child );
		}
	}

	private void function _closeDbConnection() {
		if ( StructKeyExists( variables, "dbConnection" ) ) {
			dbConnection.close();
		}
	}

	private void function _renameSqlLiteDb( required string rootDir ) {
		FileMove( rootDir & "docSet.db", rootDir & "docSet.dsidx" );
	}
}