# Kong skip-plugins Plugin
## Overview
This plugin will take the list of Plugin Names and skips the Execution of those Plugins in the Request Cycle .
This is mainly designed to skip the execution of global plugins for a specific service or route.
This will also try to solve the issue raised here  https://github.com/Kong/kong/discussions/7289

## Tested in Kong Release
Kong Enterprise 2.1.4.4

## Installation
### Recommended
```
$ git clone https://github.com/satyajitsial/skip-plugins
$ cd skip-plugins
$ luarocks make kong-plugin-skip-plugins-0.1.0-1.rockspec
```
### Other

```
$ git clone https://github.com/satyajitsial/skip-plugins
$ cd skip-plugins
$ luarocks install kong-plugin-skip-plugins-0.1.0-1.all.rock
```
After Installing the Plugin using any of the above steps . Add the Plugin Name in Kong.conf

```
plugins = bundled,skip-plugins

```
### Restart Kong

```
kong restart

```
# Configuration Reference

## Enable the plugin on a service

### Admin-API
For example, configure this plugin on a service by making the following request:
		
	curl -X POST http://{HOST}:8001/services/{SERVICE}/plugins \
	--data "name=skip-plugins"  \
	--data "config.plugin_names={PLUGIN_NAMES}"

### Declarative(YAML)
For example, configure this plugin on a service by adding this section to your declarative configuration file:
			
	services : 
	 name: {SERVICE}
	 plugins:
	 - name: skip-plugins
	 config:
	   plugin_names: {PLUGIN_NAMES}
	 enabled: true
	 protocols:
	 - grpc
	 - grpcs
	 - http
	 - https

SERVICE is the id or name of the service that this plugin configuration will target.
PLUGIN_NAMES is the name of the plugin or list of plugin Names to be skipped.

## Enable the plugin on a Route

### Admin-API
For example, configure this plugin on a route with:

	curl -X POST http://{HOST}:8001/services/{ROUTE}/plugins \
	--data "name=skip-plugins"  \
	--data "config.plugin_names={PLUGIN_NAMES}"
### Declarative(YAML)
For example, configure this plugin on a route by adding this section to your declarative configuration file:

	services : 
	 name: {ROUTE}
	 plugins:
	 - name: skip-plugins
	 config:
	   plugin_names: {PLUGIN_NAMES}
	 enabled: true
	 protocols:
	 - grpc
	 - grpcs
	 - http
	 - https

ROUTE is the id or name of the route that this plugin configuration will target.
PLUGIN_NAMES is the name of the plugin or list of plugin Names to be skipped.

## Parameters

| FORM PARAMETER	     														| DESCRIPTION										  													|
| ----------- 																		| -----------																								|
| name<br>Type:string  														|  The name of the plugin to use, in this case skip-plugins |
| service.id<br>Type:string  										  |  The ID of the Service the plugin targets.								|
| route.id<br>Type:string   											|  The ID of the Route  the plugin targets.									|
| enabled<br>Type:boolean<br>Default value:true   |  Whether this plugin will be applied.										  |
| config.plugin_names<br>Type:string              |  Accepts a pluginname or list of plugin names to be skipped sparated by comma(,)|


## Error code

| Request	     														| Response Code				 |       Response									|
| ----------- 														| -----------					 | -----------	                  |
| Input Plugin name is empty or space  		|  400								 | "message": "skip-plugins : pluginName is Empty"|


## Known Limitation
The Plugin doesn't skip the Execution of other plugins in the Response cycle .


## Contributors
Developed By : Satyajit.Sial@VERIFONE.com <br>
Designed By  : Vineet.Dutt@VERIFONE.com , Prema.Namasivayam@VERIFONE.com
			         