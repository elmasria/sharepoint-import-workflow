# SharePoint Import Workflow Client Side

This Application help SharePoint users to import Nintex workflow using a Power-Shell script and a configuration file **_configuration.json_**.

## Run Application

1. Clone / download the project
2. List and workflow should be configured in the **_configuration.json_** file.

### configuration.json

```json

{
 "webURL": "",
 "MixedAuthenticationMode":true,
 "useStaticCredentials":true,
 "username":"",
 "password":"",
 "domain":"duqm.local",
 "Lists": [
	 {
		 "Title":"LIST_NAME",
		 "workflowLocation":"C:\\WF_NAME.nwf",
		 "workflowName":"WF_NAME"

	 }
 ]
}



```

1. **webURL** : The target site collection user need to create the lists in.
2. **Lists** : Array that contains list of Lists that should be created.
	1. **Title** : List name
	3. **workflowLocation** : location path on hard disk
	4. **workflowName** : Name of the workflow	 
