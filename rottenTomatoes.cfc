component {
	// cfprocessingdirective( preserveCase=true );

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
		this.userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.117 Safari/537.36";
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
			var info= ( isSimpleValue( arguments.input ) ? arguments.input : serializeJson( arguments.input ) );
			cftrace(
				var= "info"
			,	category= "RottenTomatoes"
			,	type= "information"
			);
		}
		return;
	}

	struct function apiRequest( required string path ) {
		var http = {};
		var item = "";
		var out = {
			success = false
		,	error = ""
		,	status = ""
		,	statusCode = 0
		,	response = ""
		,	requestUrl = this.apiUrl & arguments.path
		,	delay= 0
		};
		arguments[ "apikey" ] = this.apiKey;
		structDelete( arguments, "path" );
		out.requestUrl &= this.structToQueryString( arguments );
		this.debugLog( out.requestUrl );
		// this.debugLog( out );
		// throttle requests by sleeping the thread to prevent overloading api
		if ( this.lastRequest > 0 && this.throttle > 0 ) {
			out.delay = this.throttle - ( getTickCount() - this.lastRequest );
			if ( out.delay > 0 ) {
				this.debugLog( "Pausing for #out.delay#/ms" );
				sleep( out.delay );
			}
		}
		cftimer( type="debug", label="tomato request " & out.requestUrl ) {
			cfhttp( result="http", method="GET", url=out.requestUrl, charset="UTF-8", throwOnError=false, timeOut=this.httpTimeOut, userAgent= this.userAgent );
			if ( this.throttle > 0 ) {
				this.lastRequest= getTickCount();
				server.rt_lastRequest= this.lastRequest;
			}
		}
		out.response = toString( http.fileContent );
		// this.debugLog( http );
		// this.debugLog( out.response );
		out.statusCode = http.responseHeader.Status_Code ?: 500;
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
		this.debugLog( out.statusCode & " " & out.error );
		return out;
	}

	struct function httpRequest( required string url, boolean parse= true ) {
		var http = {};
		var item = "";
		var out = {
			success = false
		,	error = ""
		,	status = ""
		,	statusCode = 0
		,	response = ""
		,	requestUrl = arguments.url
		,	delay= 0
		};
		var p = arguments.parse;
		structDelete( arguments, "url" );
		structDelete( arguments, "parse" );
		out.requestUrl &= this.structToQueryString( arguments );
		this.debugLog( out.requestUrl );
		// this.debugLog( out );
		// throttle requests by sleeping the thread to prevent overloading api
		if ( this.lastRequest > 0 && this.throttle > 0 ) {
			out.delay = this.throttle - ( getTickCount() - this.lastRequest );
			if ( out.delay > 0 ) {
				this.debugLog( "Pausing for #out.delay#/ms" );
				sleep( out.delay );
			}
		}
		cftimer( type="debug", label="tomato request " & out.requestUrl ) {
			cfhttp( result="http", method="GET", url=out.requestUrl, charset="UTF-8", throwOnError=false, timeOut=this.httpTimeOut, userAgent= this.userAgent );
			if ( this.throttle > 0 ) {
				this.lastRequest= getTickCount();
				server.rt_lastRequest= this.lastRequest;
			}
		}
		out.response = toString( http.fileContent );
		// this.debugLog( http );
		// this.debugLog( out.response );
		out.statusCode = http.responseHeader.Status_Code ?: 500;
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.error = "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error = out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success = true;
		}
		// parse response 
		if ( len( out.response ) && p ) {
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
		this.debugLog( out.statusCode & " " & out.error );
		return out;
	}

	struct function moviePage( required string slug ) {
		var out = this.httpRequest(
			url= "https://www.rottentomatoes.com" & arguments.slug
		,	parse= false
		);
		return out;
	}

	struct function moviePageID( required string slug ) {
		var out = this.httpRequest(
			url= "https://www.rottentomatoes.com" & arguments.slug
		,	parse= false
		);
		out.movieID = 0;
		//return reReplaceNoCase( out.response, '.+field[rtid]":"([^"]+)".+', '\1' );
		if( out.success ) {
			out.first = find( 'field[rtid]":"', out.response ) + 14;
			if( out.first > 1 ) {
				out.end = find( '"', out.response, out.first );
				out.movieID = mid( out.response, out.first, out.end-out.first );
			} else {
				// return reReplaceNoCase( out.response, '.+data-movie-id="([^"]+)".+', '\1' );
				out.first = find( 'data-movie-id="', out.response ) + 15;
				if( out.first > 1 ) {
					out.end = find( '"', out.response, out.first );
					out.movieID = mid( out.response, out.first, out.end-out.first );
				} else {
					out.error= "couldn't parse movie id";
					out.success= false;
				}
			}
		}
		return out;
	}

	struct function movie( required numeric id ) {
		var out = this.httpRequest(
			url= "https://www.rottentomatoes.com/api/private/v1.0/movies/#numberFormat( arguments.id, '00' )#"
		);
		// https://api.flixster.com/android/api/v2/movies/#arguments.id#.json
		return out;
	}

	struct function movieAlt( required numeric id ) {
		var out = this.httpRequest(
			url= "https://api.flixster.com/android/api/v2/movies/#arguments.id#.json"
		);
		return out;
	}

	struct function searchAlt( required string query, string type, numeric offset= 0, numeric limit= 5 ) {
		var out = this.httpRequest(
			url= "https://www.rottentomatoes.com/napi/search/"
		,	argumentCollection= arguments
		);
		return out;
	}
	struct function movieSearch( required string query, numeric offset= 0, numeric limit= 30 ) {
		return this.searchAlt( type= "movie", argumentCollection= arguments );
	}
	struct function tvSearch( required string query, numeric offset= 0, numeric limit= 30 ) {
		return this.searchAlt( type= "tvSeries", argumentCollection= arguments );
	}
	struct function franchiseSearch( required string query, numeric offset= 0, numeric limit= 30 ) {
		return this.searchAlt( type= "franchise", argumentCollection= arguments );
	}
	struct function actorSearch( required string query, numeric offset= 0, numeric limit= 30 ) {
		return this.searchAlt( type= "actor", argumentCollection= arguments );
	}

	// https://www.rottentomatoes.com/api/private/v2.0/browse?dvd-streaming-upcoming

	// https://www.rottentomatoes.com/api/private/v2.0/search/default-list 


	// type=dvd-streaming-upcoming == Coming Soon
	// type=cf-dvd-streaming-all == Certified Fresh Movies
	// type=dvd-streaming-all == Browse All
	// type=top-dvd-streaming == Top DVD & Streaming
	// type=dvd-streaming-new == New Releases

	
	// type=cf-in-theaters == (theatre) Certified Fresh Movies
	// type=opening == (threatre) Opening This Week
	// type=in-theaters == (theatre) Top Box Office
	// type=upcoming == (theatre) Coming Soon

	// type=tv-list-1 = New TV Tonight
	// type=tv-list-2 = Most Popular TV on RT
	// type=tv-list-3 = Certified Fresh TV

	// sortBy=tomato
	// sortBy=release
	// sortBy=popularity


	struct function listDVD( numeric page= 1, numeric limit= 32 ) {
		arguments.type= "dvd-streaming-all"
		var out = this.httpRequest(
			url= "https://www.rottentomatoes.com/api/private/v2.0/browse"
		,	argumentCollection= arguments
		);
		return out;
	}

	struct function freshDVD( numeric page= 1, numeric limit= 32 ) {
		arguments.type= "cf-dvd-streaming-all"
		var out = this.httpRequest(
			url= "https://www.rottentomatoes.com/api/private/v2.0/browse"
		,	argumentCollection= arguments
		);
		return out;
	}

	struct function browse( numeric page= 1, string sortBy= "release" ) {
		var args = {
			"minTomato"= 70
		,	"maxTomato"= 100
		,	"sortBy"= arguments.sortBy
		,	"type"= "cf-dvd-streaming-all"
		,	"page"= arguments.page
		};
		var out = this.httpRequest(
			url= "https://www.rottentomatoes.com/api/private/v2.0/browse"
		,	argumentCollection= args
		);
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
					sValue = stInput[ sItem ] ?: "";
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
