#include "HandelConnection.h"
#include <functional>

CConnectionHandler::CConnectionHandler()
{
	Failed = false;
	
	l = lua_open();
	
	luaL_openlibs(l);
	
	lua_pushcfunction(l, l_Print);
	lua_setglobal(l, "Print");
	
	if( luaL_loadfile(l, "main.lua") || lua_pcall(l, 0, 0, 0))
	{
		printf("error: %s", lua_tostring(l, -1));
		Failed = true;
		return;
	}
}
CConnectionHandler::~CConnectionHandler()
{
	lua_close(l);
}


// This was going to be a lambada but, well, I guess not as you cant pass a labada function that captures a var to a funciton pointer...........
lua_State* g_pLs = 0;
int SetLuaConnectionValues(void *cls, enum MHD_ValueKind kind, const char *key, const char *value)
{
	const char* type;
	
	switch(kind)
	{
	case MHD_GET_ARGUMENT_KIND:
		type = "GET";
		break;
	case MHD_HEADER_KIND:
		type = "HEADER";
		break;
	case MHD_COOKIE_KIND:
		type = "COOKIE";
		break;
	case MHD_POSTDATA_KIND:
		type = "POST";
		break;
	case MHD_RESPONSE_HEADER_KIND:
		type = "RHEADER";
		break;
	case MHD_FOOTER_KIND:
		type = "FOOTER";
		break;
	default:
		return MHD_YES;
	}
	
	lua_pushstring(g_pLs, type); 		// Push the string
	lua_gettable(g_pLs, -2);			// Get the table the corrosponds to it, and put it on the stack
		lua_pushstring(g_pLs, key);		// Push key and value to the stack
		lua_pushstring(g_pLs, value);
		lua_rawset(g_pLs, -3);			// Tell lua to add them to the table
	lua_pop(g_pLs, 1); 					// I don't recall which this pops (table or string(type)); it's one of them...
	
	return MHD_YES;
}

void CConnectionHandler::Handel(connection_t* connection, MHD_Connection* mhdcon, todo_t& todo)
{
	if(Failed)
		return;

	lua_getglobal(l, "main");
	if(!lua_isfunction(l,-1))
	{
		lua_pop(l,1);
		return;
	}
	
	lua_newtable(l); // con table
	
	lua_pushstring(l, "url");
	lua_pushstring(l, connection->url.c_str());
	lua_rawset(l, -3);
	
	lua_pushstring(l, "method");
	lua_pushstring(l, connection->method.c_str());
	lua_rawset(l, -3);
	
	lua_pushstring(l, "version");
	lua_pushstring(l, connection->version.c_str());
	lua_rawset(l, -3);
	
	lua_pushstring(l, "response");
	lua_pushstring(l, connection->response.c_str());
	lua_rawset(l, -3);
	
	lua_pushstring(l, "GET");
	lua_newtable(l);
	lua_rawset(l, -3);
	
	lua_pushstring(l, "HEADER");
	lua_newtable(l);
	lua_rawset(l, -3);
	
	lua_pushstring(l, "COOKIE");
	lua_newtable(l);
	lua_rawset(l, -3);
	
	lua_pushstring(l, "POST");
	lua_newtable(l);
	lua_rawset(l, -3);
	
	lua_pushstring(l, "RHEADER");
	lua_newtable(l);
	lua_rawset(l, -3);
	
	lua_pushstring(l, "FOOTER");
	lua_newtable(l);
	lua_rawset(l, -3);
	
	
	MHD_KeyValueIterator itt_key = &SetLuaConnectionValues;
	
	while(g_pLs)
		usleep(0010000); // 0.01 seconds
	
	
	g_pLs = l;
	
	// Now lets make it call our lambada
	MHD_get_connection_values(mhdcon, MHD_HEADER_KIND, 				itt_key, NULL);
	MHD_get_connection_values(mhdcon, MHD_COOKIE_KIND, 				itt_key, NULL);
	MHD_get_connection_values(mhdcon, MHD_POSTDATA_KIND, 			itt_key, NULL);
	MHD_get_connection_values(mhdcon, MHD_GET_ARGUMENT_KIND, 		itt_key, NULL);
	MHD_get_connection_values(mhdcon, MHD_FOOTER_KIND, 				itt_key, NULL);
	MHD_get_connection_values(mhdcon, MHD_RESPONSE_HEADER_KIND, 	itt_key, NULL);
	
	g_pLs = 0;
	
	// 1 argument, 1 result
	if (lua_pcall(l, 1, 1, 0)) 
	{
		printf("error running function `main': %s\n", lua_tostring(l, -1));
		connection->response = "Lua error!";
		connection->errcode = MHD_HTTP_INTERNAL_SERVER_ERROR;
		return;
	}else{
		lua_pushstring(l, "response");
		{
			lua_gettable(l, -2);

			if(lua_isstring(l, -1))
				connection->response = lua_tostring(l, -1);
			
		}
		lua_pop(l, 1); // "response"
		
		lua_pushstring(l, "errcode");
		{
			lua_gettable(l, -2);

			if(lua_isnumber(l, -1))
				connection->errcode = (int)lua_tonumber(l, -1);
		}
		lua_pop(l, 1);
		
		lua_pushstring(l, "response_headers");
		{
			lua_gettable(l, -2);

			lua_pushnil(l);

			while(lua_next(l, -2) != 0)
			{
				todo.response_headers.insert(ResponseHeadersMap::value_type(lua_tostring(l, -2), lua_tostring(l, -1)));
				lua_pop(l, 1);
			}
		}
		lua_pop(l, 1); // "response"
	}
	
	lua_pop(l, 1); // The retun table
	
	int stackpos = lua_gettop(l);
	if(stackpos)
		printf("WARNING: stack not at 0 (%i)\n", stackpos);
}
