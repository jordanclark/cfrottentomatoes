component {

	function init(
		required string apiKey
	,	string apiUrl= "http://api.rottentomatoes.com/api/public/v1.0/"
	,	numeric throttle= 500
	,	numeric httpTimeOut= 60
	) {
		this.apiKey = arguments.apiKey;
		this.apiUrl = arguments.apiUrl;
		this.httpTimeOut = arguments.httpTimeOut;
		this.throttle = arguments.throttle;
		this.lastRequest= server.rt_lastRequest ?: 0;
		return this;
	}

	function debugLog( required input ) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "RottenTomatoes: " & arguments.input );
			} else {
				request.log( "RottenTomatoes: (complex type)" );
				request.log( arguments.input );
			}
		} else {
			cftrace( text=( isSimpleValue( arguments.input ) ? arguments.input : "" ), var=arguments.input, category="RottenTomatoes", type="information" );
		}
		return;
	}

	struct function apiRequest( required string path ) {
		var http = {};
		var dataKeys = 0;
		var item = "";
		var out = {
			success = false
		,	error = ""
		,	status = ""
		,	statusCode = 0
		,	response = ""
		,	requestUrl = this.apiUrl & arguments.path
		};
		arguments[ "apikey" ] = this.apiKey;
		structDelete( arguments, "path" );
		out.requestUrl &= this.structToQueryString( arguments );
		this.debugLog( out.requestUrl );
		// this.debugLog( out );
		// throttle requests by sleeping the thread to prevent overloading api
		if ( this.lastRequest > 0 && this.throttle > 0 ) {
			var wait = this.throttle - ( getTickCount() - this.lastRequest );
			if ( wait > 0 ) {
				this.debugLog( "Pausing for #wait#/ms" );
				sleep( wait );
			}
		}
		cftimer( type="debug", label="tomatoe request" ) {
			cfhttp( result="http", method="GET", url=out.requestUrl, charset="UTF-8", throwOnError=false, timeOut=this.httpTimeOut );
			if ( this.throttle > 0 ) {
				this.lastRequest= getTickCount();
				server.lastfm_lastRequest= this.lastRequest;
			}
		}
		out.response = toString( http.fileContent );
		// this.debugLog( http );
		// this.debugLog( out.response );
		out.statusCode = http.responseHeader.Status_Code ?: 500;
		this.debugLog( out.statusCode );
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.error = "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error = out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success = true;
		}
		// parse response 
		if ( len( out.response ) ) {
			try {
				out.json = deserializeJSON( out.response );
				if ( isStruct( out.json ) && structKeyExists( out.json, "status" ) && out.json.status == "error" ) {
					out.success = false;
					out.error = out.json.message;
				}
				if ( structCount( out.json ) == 1 ) {
					out.json = out.json[ structKeyList( out.json ) ];
				}
			} catch (any cfcatch) {
				out.error= "JSON Error: " & (cfcatch.message?:"No catch message") & " " & (cfcatch.detail?:"No catch detail");
			}
		}
		if ( len( out.error ) ) {
			out.success = false;
		}
		return out;
	}

	struct function search( required string q, numeric limit= 30, numeric page= 1 ) {
		var args = {
			"q" = arguments.q
		,	"page_limit" = arguments.limit
		,	"page" = arguments.page
		};
		var out = this.apiRequest(
			path= "movies.json"
		,	argumentCollection= args
		);
		return out;
	}

	struct function reviews( required string id, string type= "all", numeric limit= 30, numeric page= 1, string country= "US" ) {
		var args = {
			"review_type" = arguments.type
		,	"page_limit" = arguments.limit
		,	"page" = arguments.page
		,	"country" = arguments.country
		};
		var out = this.apiRequest(
			path= "movies/#arguments.id#/reviews.json"
		,	argumentCollection= args
		);
		return out;
	}

	struct function similar( required string id, numeric limit= 5 ) {
		var args = {
			"limit" = arguments.limit
		};
		var out = this.apiRequest(
			path= "movies/#arguments.id#/similar.json"
		,	argumentCollection= args
		);
		return out;
	}

	string function structToQueryString( required struct stInput, boolean bEncode= true, string lExclude= "", string sDelims= "," ) {
		var sOutput = "";
		var sItem = "";
		var sValue = "";
		var amp = "?";
		for ( sItem in stInput ) {
			if ( !len( lExclude ) || !listFindNoCase( lExclude, sItem, sDelims ) ) {
				try {
					sValue = stInput[ sItem ];
					if ( len( sValue ) ) {
						if ( bEncode ) {
							sOutput &= amp & lCase( sItem ) & "=" & urlEncodedFormat( sValue );
						} else {
							sOutput &= amp & lCase( sItem ) & "=" & sValue;
						}
						amp = "&";
					}
				} catch (any cfcatch) {
				}
			}
		}
		return sOutput;
	}

}
